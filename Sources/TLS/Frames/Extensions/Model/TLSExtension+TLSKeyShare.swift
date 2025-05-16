//
//  TLSExtension+TLSKeyShare.swift
//  Swifter
//
//  Created by Tomasz on 14/05/2025.
//
import Foundation
import SwiftExtensions

extension TLSExtension {
    var asClientHelloKeyShare: [TLSKeyShare]? {
        get throws {
            guard self.type == .keyShare else { return nil }
            let factory = try TLSKeyShareFactory(rawBody: rawBody)
            return factory.keyShares
        }
    }
}

enum TLSKeyShareFactoryError: Error {
    case invalidByteCount
}

fileprivate class TLSKeyShareFactory {
    let keyShares: [TLSKeyShare]
    
    init(rawBody: Data) throws {
        var keys: [TLSKeyShare] = []
        var rawBody = rawBody
        
        let bodyLenght = try rawBody.consume(bytes: 2).uInt16
        guard bodyLenght > 3 else {
            throw TLSKeyShareFactoryError.invalidByteCount
        }
        while rawBody.isEmpty.not {
            // 2 bytes - named group
            // 2 bytes - key length
            // n bytes - key
            let namedGroup = TLSNamedGroup(rawValue: try rawBody.consume(bytes: 2).uInt16)
            let keySize = try rawBody.consume(bytes: 2).uInt16
            let key = rawBody.consume(bytes: Int(keySize))
            if let namedGroup {
                keys.append(TLSKeyShare(namedGroup: namedGroup, key: key))
            }
        }
        
        self.keyShares = keys
    }
}
