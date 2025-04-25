//
//  TLSRandom.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import Foundation

enum TLSRandomError: Error {
    case invalidRandomBytesCount
}

struct TLSRandom {
    private static let numberOfRandomBytes = 32
    var randomBytes: Data

    init(_ bytes: [UInt8]) throws {
        guard bytes.count == Self.numberOfRandomBytes else {
            throw TLSRandomError.invalidRandomBytesCount
        }
        self.randomBytes = bytes.data
    }
}
