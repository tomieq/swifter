//
//  Socket.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public enum SocketError: Error {
    case socketCreationFailed(String)
    case socketSettingReUseAddrFailed(String)
    case bindFailed(String)
    case listenFailed(String)
    case writeFailed(String)
    case getPeerNameFailed(String)
    case convertingPeerNameFailed
    case getNameInfoFailed(String)
    case acceptFailed(String)
    case recvFailed(String)
    case lineTooLong
    case getSockNameFailed(String)
}

// swiftlint: disable identifier_name
open class Socket: @unchecked Sendable, Hashable, Equatable {
    let id = UUID()
    let socketFileDescriptor: Int32
    private var shutdown = false
    let transferCounter = TransferCounter()

    public init(socketFileDescriptor: Int32) {
        self.socketFileDescriptor = socketFileDescriptor
    }

    deinit {
        close()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.socketFileDescriptor)
    }

    public func close() {
        if self.shutdown {
            return
        }
        self.shutdown = true
        Socket.close(self.socketFileDescriptor)
    }

    /// Set send/receive timeouts (in seconds) on this socket.
    public func setTimeouts(seconds: Int) {
        var tv = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(self.socketFileDescriptor, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(self.socketFileDescriptor, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    public var port: in_port_t {
        get throws {
            var addr = sockaddr_in()
            return try withUnsafePointer(to: &addr) { pointer in
                var len = socklen_t(MemoryLayout<sockaddr_in>.size)
                if getsockname(self.socketFileDescriptor, UnsafeMutablePointer(OpaquePointer(pointer)), &len) != 0 {
                    throw SocketError.getSockNameFailed(Errno.description())
                }
                let sin_port = pointer.pointee.sin_port
                #if os(Linux)
                return ntohs(sin_port)
                #else
                return Int(OSHostByteOrder()) != OSLittleEndian ? sin_port.littleEndian : sin_port.bigEndian
                #endif
            }
        }
    }

    public func isIPv4() throws -> Bool {
        var addr = sockaddr_in()
        return try withUnsafePointer(to: &addr) { pointer in
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            if getsockname(self.socketFileDescriptor, UnsafeMutablePointer(OpaquePointer(pointer)), &len) != 0 {
                throw SocketError.getSockNameFailed(Errno.description())
            }
            return Int32(pointer.pointee.sin_family) == AF_INET
        }
    }

    public func writeUTF8(_ string: String) throws {
        try self.writeUInt8(ArraySlice(string.utf8))
    }

    public func writeUInt8(_ data: [UInt8]) throws {
        try self.writeUInt8(ArraySlice(data))
    }

    public func writeUInt8(_ data: ArraySlice<UInt8>) throws {
        try data.withUnsafeBufferPointer {
            try self.writeBuffer($0.baseAddress!, length: data.count)
        }
    }

    public func writeData(_ data: NSData) throws {
        try self.writeBuffer(data.bytes, length: data.length)
    }

    public func writeData(_ data: Data) throws {
        #if compiler(>=5.0)
        try data.withUnsafeBytes { (body: UnsafeRawBufferPointer) -> Void in
            if let baseAddress = body.baseAddress, body.count > 0 {
                let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
                try self.writeBuffer(pointer, length: data.count)
            }
        }
        #else
        try data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> Void in
            try self.writeBuffer(pointer, length: data.count)
        }
        #endif
    }

    private func writeBuffer(_ pointer: UnsafeRawPointer, length: Int) throws {
        var sent = 0
        defer {
            transferCounter.countBytes(UInt64(sent))
        }
        while sent < length {
            #if os(Linux)
            let result = send(self.socketFileDescriptor, pointer + sent, Int(length - sent), Int32(MSG_NOSIGNAL))
            #else
            let result = write(self.socketFileDescriptor, pointer + sent, Int(length - sent))
            #endif
            if result <= 0 {
                throw SocketError.writeFailed(Errno.description())
            }
            sent += result
        }
    }

    /// Read a single byte off the socket. This method is optimized for reading
    /// a single byte. For reading multiple bytes, use read(length:), which will
    /// pre-allocate heap space and read directly into it.
    ///
    /// - Returns: A single byte
    /// - Throws: SocketError.recvFailed if unable to read from the socket
    open func read() throws -> UInt8 {
        var byte: UInt8 = 0

        #if os(Linux)
        let count = Glibc.read(self.socketFileDescriptor as Int32, &byte, 1)
        #else
        let count = Darwin.read(self.socketFileDescriptor as Int32, &byte, 1)
        #endif

        guard count > 0 else {
            throw SocketError.recvFailed(Errno.description())
        }
        return byte
    }

    /// Read up to `length` bytes from this socket
    ///
    /// - Parameter length: The maximum bytes to read
    /// - Returns: A buffer containing the bytes read
    /// - Throws: SocketError.recvFailed if unable to read bytes from the socket
    open func read(length: Int) throws -> [UInt8] {
        return try [UInt8](unsafeUninitializedCapacity: length) { buffer, bytesRead in
            bytesRead = try read(into: &buffer, length: length)
        }
    }

    static let kBufferLength = 1024

    /// Read up to `length` bytes from this socket into an existing buffer
    ///
    /// - Parameter into: The buffer to read into (must be at least length bytes in size)
    /// - Parameter length: The maximum bytes to read
    /// - Returns: The number of bytes read
    /// - Throws: SocketError.recvFailed if unable to read bytes from the socket
    func read(into buffer: inout UnsafeMutableBufferPointer<UInt8>, length: Int) throws -> Int {
        var offset = 0
        guard let baseAddress = buffer.baseAddress else { return 0 }

        while offset < length {
            // Compute next read length in bytes. The bytes read is never more than kBufferLength at once.
            let readLength = offset + Socket.kBufferLength < length ? Socket.kBufferLength : length - offset

            #if os(Linux)
            let bytesRead = Glibc.read(self.socketFileDescriptor as Int32, baseAddress + offset, readLength)
            #else
            let bytesRead = Darwin.read(self.socketFileDescriptor as Int32, baseAddress + offset, readLength)
            #endif

            guard bytesRead > 0 else {
                throw SocketError.recvFailed(Errno.description())
            }

            offset += bytesRead
        }

        return offset
    }

    private static let CR: UInt8 = 13
    private static let NL: UInt8 = 10
    /// Maximum allowed length for a single incoming header/status line. Protects
    /// against extremely long lines used to exhaust memory.
    private static let maxLineLength = 8192

    public func readLine() throws -> String {
        var characters: String = ""
        var index: UInt8 = 0
        repeat {
            index = try self.read()
            if index > Socket.CR {
                // Enforce a maximum line length
                guard characters.utf8.count < Socket.maxLineLength else { throw SocketError.lineTooLong }
                characters.append(Character(UnicodeScalar(index)))
            }
        } while index != Socket.NL
        return characters
    }

    public lazy var peerIP: String? = {
        var addr = sockaddr_storage()
        var addrLen = socklen_t(MemoryLayout<sockaddr_storage>.size)

        if getpeername(self.socketFileDescriptor, withUnsafeMutablePointer(to: &addr) {
            UnsafeMutableRawPointer($0).assumingMemoryBound(to: sockaddr.self)
        }, &addrLen) != 0 {
            return nil
        }

        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getnameinfo($0, addrLen, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST)
            }
        }
        let endIndex = hostBuffer.firstIndex(of: 0) ?? hostBuffer.count
        let bytes = hostBuffer[..<endIndex].map { UInt8(bitPattern: $0) }
        return result == 0 ? String(decoding: bytes, as: UTF8.self) : nil
    }()

    public class func setNoSigPipe(_ socket: Int32) {
        #if os(Linux)
        // There is no SO_NOSIGPIPE in Linux (nor some other systems). You can instead use the MSG_NOSIGNAL flag when calling send(),
        // or use signal(SIGPIPE, SIG_IGN) to make your entire application ignore SIGPIPE.
        #else
        // Prevents crashes when blocking calls are pending and the app is paused ( via Home button ).
        var no_sig_pipe: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &no_sig_pipe, socklen_t(MemoryLayout<Int32>.size))
        #endif
    }

    public class func close(_ socket: Int32) {
        #if os(Linux)
        _ = Glibc.close(socket)
        #else
        _ = Darwin.close(socket)
        #endif
    }
}

public func == (socket1: Socket, socket2: Socket) -> Bool {
    return socket1.socketFileDescriptor == socket2.socketFileDescriptor
}
