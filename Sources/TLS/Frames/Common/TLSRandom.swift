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

extension TLSRandom {
    // special HRR random sent to client in ServerHello to force client to send fixed ClientHello
    static var hrr: TLSRandom {
        get throws {
            try TLSRandom([0xCF, 0x21, 0xAD, 0x74, 0xE5, 0x9A, 0x61, 0x11,
                           0xBE, 0x1D, 0x8C, 0x02, 0x1E, 0x65, 0xB8, 0x91,
                           0xC2, 0xA2, 0x11, 0x16, 0x7A, 0xBB, 0x8C, 0x5E,
                           0x07, 0x9E, 0x09, 0xE2, 0xC8, 0xA8, 0x33, 0x9C])
        }
    }
}
