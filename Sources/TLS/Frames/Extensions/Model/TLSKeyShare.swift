//
//  TLSKeyShare.swift
//  Swifter
//
//  Created by Tomasz on 25/04/2025.
//
import Foundation

struct TLSKeyShare {
    let namedGroup: TLSNamedGroup
    let key: Data
}

extension TLSKeyShare: CustomStringConvertible {
    var description: String {
        "group: \(namedGroup.string) size: \(DataSize(key.count))"
    }
}

extension TLSKeyShare: TLSOutMessage {
    var serialised: Data {
        namedGroup.rawValue.data
            .appending(key)
    }
}

extension TLSKeyShare {
    var asExtension: TLSExtension {
        TLSExtension(type: .keyShare, rawBody: serialised)
    }
}
