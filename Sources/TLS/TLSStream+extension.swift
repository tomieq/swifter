//
//  Socket+TLS.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import Foundation

extension TLSStream {

    func read(length: UInt8) throws -> [UInt8] {
        try self.read(length: Int(length))
    }
    
    func read(length: UInt16) throws -> [UInt8] {
        try self.read(length: Int(length))
    }
    
    func readUInt16() throws -> UInt16 {
        try self.read(length: 2).data.uInt16
    }
    
    func readUInt24() throws -> Int {
        let bytes = try self.read(length: 3)
        return Int(bytes[0]) << 16 + Int(bytes[1]) << 8 + Int(bytes[2])
    }
    
    func readUInt32() throws -> UInt32 {
        try self.read(length: 4).data.uInt32
    }
}

extension Int {
    var threeBytes: Data {
        Data([UInt8(self >> 16 & 0xFF),
              UInt8(self >> 8 & 0xFF),
              UInt8(self & 0xFF)])
    }
}
