//
//  TLSSupportedVersions.swift
//  Swifter
//
//  Created by Tomasz on 25/04/2025.
//
import SwiftExtensions

enum TLSSupportedVersionsError: Error {
    case invalidBytesSize(expected: Int, received: Int)
}

struct TLSSupportedVersions {
    let versions: [TLSVersion]
    
    init(bytes: [UInt8]) throws {
        guard bytes.isEmpty.not else {
            versions = []
            return
        }
        let lenght = bytes[0]
        
        let expectedLength =  1 + lenght
        guard bytes.count == expectedLength else {
            throw TLSSupportedVersionsError.invalidBytesSize(expected: Int(expectedLength), received: bytes.count)
        }
        versions = (0..<lenght/2).compactMap { index in
            let offset = Int(1 + index * 2)
            let byte = bytes[offset...]
            return TLSVersion(rawValue: byte.array.data.uInt16)
        }
    }
}
