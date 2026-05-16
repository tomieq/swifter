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
    func readLine() throws -> String
    func read() throws -> UInt8
    func read(length: Int) throws -> [UInt8]
    func writeUTF8(_ string: String) throws
    func writeUInt8(_ data: [UInt8]) throws
    func writeUInt8(_ data: ArraySlice<UInt8>) throws
    func writeData(_ data: Data) throws
    func writeData(_ data: NSData) throws
    func writeFile(_ file: String.File) throws
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

    func read() throws -> UInt8 {
        try self.socket.read()
    }

    func readLine() throws -> String {
        try self.socket.readLine()
    }

    func read(length: Int) throws -> [UInt8] {
        try self.socket.read(length: length)
    }

    func writeUTF8(_ string: String) throws {
        try self.socket.writeUTF8(string)
    }

    func writeUInt8(_ data: [UInt8]) throws {
        try self.socket.writeUInt8(data)
    }

    func writeUInt8(_ data: ArraySlice<UInt8>) throws {
        try self.socket.writeUInt8(data)
    }

    func writeData(_ data: Data) throws {
        try self.socket.writeData(data)
    }

    func writeData(_ data: NSData) throws {
        try self.socket.writeData(data)
    }

    func writeFile(_ file: String.File) throws {
        try self.socket.writeFile(file)
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
