//
//  SecureSocket.swift
//  Swifter
//
//  Created by Tomasz Kucharski on 09/07/2025.
//
import Foundation

public protocol SecureSocket {
    var id: UUID { get }
    var raw: Socket { get }
    func readLine() async throws -> String
    func read() async throws -> UInt8
    func read(length: Int) async throws -> [UInt8]
    func writeUTF8(_ string: String) async throws
    func writeUInt8(_ data: [UInt8]) async throws
    func writeUInt8(_ data: ArraySlice<UInt8>) async throws
    func writeData(_ data: Data) async throws
    func writeData(_ data: NSData) async throws
    func writeFile(_ file: String.File) async throws
    func close()
    var peerIP: String? { get }
}

class DefaultSecureSocket: SecureSocket {
    private let socket: Socket
    let id: UUID = UUID()

    var raw: Socket {
        self.socket
    }

    init(_ socket: Socket) {
        self.socket = socket
    }

    func read() async throws -> UInt8 {
        try await self.socket.readAsync()
    }

    func readLine() async throws -> String {
        try await self.socket.readLineAsync()
    }

    func read(length: Int) async throws -> [UInt8] {
        try await self.socket.readAsync(length: length)
    }

    func writeUTF8(_ string: String) async throws {
        try await self.socket.writeUTF8Async(string)
    }

    func writeUInt8(_ data: [UInt8]) async throws {
        try await self.socket.writeUInt8Async(data)
    }

    func writeUInt8(_ data: ArraySlice<UInt8>) async throws {
        try await self.socket.writeUInt8Async(data)
    }

    func writeData(_ data: Data) async throws {
        try await self.socket.writeDataAsync(data)
    }

    func writeData(_ data: NSData) async throws {
        try await self.socket.writeDataAsync(data)
    }

    func writeFile(_ file: String.File) async throws {
        try await self.socket.writeFileAsync(file)
    }

    func close() {
        self.socket.close()
    }

    var peerIP: String? {
        self.socket.peerIP
    }
}

extension DefaultSecureSocket: Equatable {
    static func == (lhs: DefaultSecureSocket, rhs: DefaultSecureSocket) -> Bool {
        lhs.socket == rhs.socket
    }
}

extension DefaultSecureSocket: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.socket)
    }
}
