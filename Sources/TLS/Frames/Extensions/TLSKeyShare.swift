//
//  TLSKeyShare.swift
//  Swifter
//
//  Created by Tomasz on 25/04/2025.
//
import Foundation

enum TLSKeyShareError: Error {
    case invalidByteCount
}

struct TLSKeyShare {
    let rawNamedGroup: UInt16
    let namedGroup: TLSNamedGroup?
    let key: Data
    
    init(rawBytes: Data) throws {
        guard rawBytes.count > 2 else {
            throw TLSKeyShareError.invalidByteCount
        }
        rawNamedGroup = rawBytes.uInt16
        namedGroup = TLSNamedGroup(rawValue: rawNamedGroup)
        key = rawBytes.bytes[2...].array.data
    }
}

extension TLSKeyShare: CustomStringConvertible {
    var description: String {
        "group: \(namedGroup?.string ?? "0x\(rawNamedGroup.hexString)(\(rawNamedGroup)") size: \(DataSize(key.count))"
    }
}
