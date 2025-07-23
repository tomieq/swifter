//
//  HttpResponseBodyRaw.swift
//  Swifter
//
//  Created by Tomasz Kucharski on 23/07/2025.
//
import Foundation

enum HttpResponseBodySize {
    case fixedSize(Int)
    case unknown
}

public protocol HttpResponseBodyWriter {
    func write(_ file: String.File) throws
    func write(_ data: [UInt8]) throws
    func write(_ data: ArraySlice<UInt8>) throws
    func write(_ data: NSData) throws
    func write(_ data: Data) throws
}

struct HttpResponseBodyRaw {
    let length: HttpResponseBodySize
    let write: ((HttpResponseBodyWriter) throws -> Void)?
    
    init(_ length: HttpResponseBodySize, _ write: ((HttpResponseBodyWriter) throws -> Void)?) {
        self.length = length
        self.write = write
    }
}




