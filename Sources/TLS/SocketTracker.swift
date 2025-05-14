//
//  SocketTracker.swift
//  Swifter
//
//  Created by Tomasz on 14/05/2025.
//
import Foundation

class SocketTracker {
    private let stream: TLSStream
    private var input = Data()
    private var output = Data()
    
    var inputCache: Data {
        input
    }
    
    var outputCache: Data {
        output
    }
    
    init(stream: TLSStream) {
        self.stream = stream
    }
    
    func clearInput() {
        input = Data()
    }
    
    func clearOutput() {
        output = Data()
    }
}

extension SocketTracker: TLSStream {
    func read(length: Int) throws -> [UInt8] {
        let data = try stream.read(length: length)
        input.append(data.data)
        return data
    }
    
    func read() throws -> UInt8 {
        let data = try stream.read()
        input.append(data)
        return data
    }
    
    func writeUInt8(_ data: [UInt8]) throws {
        try stream.writeUInt8(data)
        output.append(data.data)
    }
    
    func close() {
        stream.close()
    }
    
    
}
