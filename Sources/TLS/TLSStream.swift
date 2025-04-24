//
//  TLSStream.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//

protocol TLSStream {
    func read() throws -> UInt8
    func read(length: Int) throws -> [UInt8]
    func writeUInt8(_ data: [UInt8]) throws
    func close()
}
