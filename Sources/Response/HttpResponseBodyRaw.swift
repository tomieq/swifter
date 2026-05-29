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
    func write(_ file: String.File) async throws
    func write(_ data: [UInt8]) async throws
    func write(_ data: ArraySlice<UInt8>) async throws
    func write(_ data: NSData) async throws
    func write(_ data: Data) async throws
}

struct HttpResponseBodyRaw {
    let length: HttpResponseBodySize
    let write: ((HttpResponseBodyWriter) async throws -> Void)?

    init(_ length: HttpResponseBodySize, _ write: ((HttpResponseBodyWriter) async throws -> Void)?) {
        self.length = length
        self.write = write
    }
}
