//
//  TLSKeyShare.swift
//  Swifter
//
//  Created by Tomasz on 25/04/2025.
//
import Foundation

struct TLSKeyShare {
    let rawNamedGroup: UInt16
    let namedGroup: TLSNamedGroup?
    let key: Data
    
    init(namedGroup: TLSNamedGroup, key: Data = Data()) {
        self.namedGroup = namedGroup
        self.rawNamedGroup = namedGroup.rawValue
        self.key = key
    }
}

extension TLSKeyShare: CustomStringConvertible {
    var description: String {
        "group: \(namedGroup?.string ?? "0x\(rawNamedGroup.hexString)(\(rawNamedGroup))") size: \(DataSize(key.count))"
    }
}

extension TLSKeyShare: TLSOutMessage {
    var serialised: Data {
        rawNamedGroup.data
            .appending(key)
    }
}

extension TLSKeyShare {
    var asExtension: TLSExtension {
        TLSExtension(type: .keyShare, rawBody: serialised)
    }
}
