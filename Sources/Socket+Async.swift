//
//  Socket+Async.swift
//  Swifter
//

import Dispatch
import Foundation

extension Socket {
    public func setNonBlocking() throws {
        let flags = fcntl(self.socketFileDescriptor, F_GETFL, 0)
        guard flags != -1 else { throw SocketError.recvFailed(Errno.description()) }
        guard fcntl(self.socketFileDescriptor, F_SETFL, flags | O_NONBLOCK) != -1 else {
            throw SocketError.recvFailed(Errno.description())
        }
    }

    public func acceptClientSocketAsync() async throws -> Socket {
        while true {
            var addr = sockaddr_storage()
            var len = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let clientSocket = withUnsafeMutablePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(self.socketFileDescriptor, $0, &len)
                }
            }
            if clientSocket >= 0 {
                try Socket.configureAcceptedSocket(clientSocket)
                let socket = Socket(socketFileDescriptor: clientSocket)
                try socket.setNonBlocking()
                return socket
            }
            if Self.isInterruptedErrno || Self.isTransientAcceptErrno { continue }
            guard Self.isWouldBlockErrno else { throw SocketError.acceptFailed(Errno.description()) }
            try await self.waitUntilReadable()
        }
    }

    public func readAsync() async throws -> UInt8 {
        var byte: UInt8 = 0
        while true {
            #if os(Linux)
            let count = Glibc.read(self.socketFileDescriptor, &byte, 1)
            #else
            let count = Darwin.read(self.socketFileDescriptor, &byte, 1)
            #endif
            if count > 0 { return byte }
            if count == 0 { throw SocketError.recvFailed("Connection closed") }
            if Self.isInterruptedErrno { continue }
            guard Self.isWouldBlockErrno else { throw SocketError.recvFailed(Errno.description()) }
            try await self.waitUntilReadable()
        }
    }

    public func readAsync(length: Int) async throws -> [UInt8] {
        guard length > 0 else { return [] }
        var result = [UInt8]()
        result.reserveCapacity(length)
        while result.count < length {
            let chunk = try await self.readAvailableAsync(maxLength: min(Socket.kBufferLength, length - result.count))
            result.append(contentsOf: chunk)
        }
        return result
    }

    public func readLineAsync() async throws -> String {
        var characters = ""
        var index: UInt8 = 0
        repeat {
            index = try await self.readAsync()
            if index > Socket.CR {
                guard characters.utf8.count < Socket.maxLineLength else { throw SocketError.lineTooLong }
                characters.append(Character(UnicodeScalar(index)))
            }
        } while index != Socket.NL
        return characters
    }

    public func writeUTF8Async(_ string: String) async throws {
        try await self.writeUInt8Async(ArraySlice(string.utf8))
    }

    public func writeUInt8Async(_ data: [UInt8]) async throws {
        try await self.writeUInt8Async(ArraySlice(data))
    }

    public func writeUInt8Async(_ data: ArraySlice<UInt8>) async throws {
        try await self.writeBytesAsync([UInt8](data))
    }

    public func writeDataAsync(_ data: Data) async throws {
        try await self.writeBytesAsync([UInt8](data))
    }

    public func writeDataAsync(_ data: NSData) async throws {
        try await self.writeDataAsync(data as Data)
    }

    public func writeFileAsync(_ file: String.File) async throws {
        var buffer = [UInt8](repeating: 0, count: Socket.kBufferLength)
        while true {
            let readResult = fread(&buffer, 1, buffer.count, file.pointer)
            guard readResult > 0 else { break }
            try await self.writeUInt8Async(buffer.prefix(readResult))
        }
        transferCounter.countBytes(file.size)
    }

    private func readAvailableAsync(maxLength: Int) async throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: maxLength)
        while true {
            let count = buffer.withUnsafeMutableBufferPointer { pointer -> Int in
                guard let baseAddress = pointer.baseAddress else { return 0 }
                #if os(Linux)
                return Glibc.read(self.socketFileDescriptor, baseAddress, maxLength)
                #else
                return Darwin.read(self.socketFileDescriptor, baseAddress, maxLength)
                #endif
            }
            if count > 0 {
                buffer.removeSubrange(count..<buffer.count)
                return buffer
            }
            if count == 0 { throw SocketError.recvFailed("Connection closed") }
            if Self.isInterruptedErrno { continue }
            guard Self.isWouldBlockErrno else { throw SocketError.recvFailed(Errno.description()) }
            try await self.waitUntilReadable()
        }
    }

    private func writeBytesAsync(_ bytes: [UInt8]) async throws {
        guard !bytes.isEmpty else { return }
        var sent = 0
        defer { transferCounter.countBytes(UInt64(sent)) }
        while sent < bytes.count {
            let result = bytes.withUnsafeBytes { pointer -> Int in
                let start = pointer.baseAddress! + sent
                let length = bytes.count - sent
                #if os(Linux)
                return send(self.socketFileDescriptor, start, length, Int32(MSG_NOSIGNAL))
                #else
                return write(self.socketFileDescriptor, start, length)
                #endif
            }
            if result > 0 {
                sent += result
                continue
            }
            if result == 0 { throw SocketError.writeFailed("Connection closed") }
            if Self.isInterruptedErrno { continue }
            guard Self.isWouldBlockErrno else { throw SocketError.writeFailed(Errno.description()) }
            try await self.waitUntilWritable()
        }
    }

    private func waitUntilReadable() async throws {
        try Task.checkCancellation()
        #if os(Linux)
        try await Task.sleep(nanoseconds: 1_000_000)
        #else
        await withCheckedContinuation { continuation in
            let waiter = SocketReadinessWaiter()
            let source = DispatchSource.makeReadSource(fileDescriptor: self.socketFileDescriptor, queue: .global())
            waiter.source = source
            source.setEventHandler {
                source.cancel()
                SocketReadinessWaiter.release(waiter)
                continuation.resume()
            }
            SocketReadinessWaiter.retain(waiter)
            source.resume()
        }
        #endif
        try Task.checkCancellation()
    }

    private func waitUntilWritable() async throws {
        try Task.checkCancellation()
        #if os(Linux)
        try await Task.sleep(nanoseconds: 1_000_000)
        #else
        await withCheckedContinuation { continuation in
            let waiter = SocketReadinessWaiter()
            let source = DispatchSource.makeWriteSource(fileDescriptor: self.socketFileDescriptor, queue: .global())
            waiter.source = source
            source.setEventHandler {
                source.cancel()
                SocketReadinessWaiter.release(waiter)
                continuation.resume()
            }
            SocketReadinessWaiter.retain(waiter)
            source.resume()
        }
        #endif
        try Task.checkCancellation()
    }

    private static var isWouldBlockErrno: Bool { errno == EAGAIN || errno == EWOULDBLOCK }
    private static var isInterruptedErrno: Bool { errno == EINTR }

    private static var isTransientAcceptErrno: Bool {
        #if os(Linux)
        return errno == ECONNABORTED || errno == EPROTO
        #else
        return errno == ECONNABORTED
        #endif
    }
}

private final class SocketReadinessWaiter: Hashable, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var active = Set<SocketReadinessWaiter>()

    private let id = UUID()
    var source: DispatchSourceProtocol?

    static func retain(_ waiter: SocketReadinessWaiter) {
        self.lock.lock()
        self.active.insert(waiter)
        self.lock.unlock()
    }

    static func release(_ waiter: SocketReadinessWaiter) {
        self.lock.lock()
        self.active.remove(waiter)
        self.lock.unlock()
    }

    static func == (lhs: SocketReadinessWaiter, rhs: SocketReadinessWaiter) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}