//
//  TLSExtension.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import Foundation

struct TLSExtension {
    let type: TLSExtensionType?
    let rawType: UInt16
    let rawBody: Data
}

extension TLSExtension: CustomStringConvertible {
    var description: String {
        "TLSExtension type: \(type.notNil ? "\(type!)" : rawType.hexString)"
    }
}

extension TLSExtension: TLSOutMessage {
    var serialised: Data {
        rawType.data
            .appending(UInt16(rawBody.count).data)
            .appending(rawBody)
    }
}
