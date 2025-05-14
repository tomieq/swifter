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
        
        let bodyLenght = rawBody.uInt16
        guard bodyLenght > 3 else {
            throw TLSKeyShareFactoryError.invalidByteCount
        }
        var offset = 2
        while offset < rawBody.count {
            // 2 bytes - named group
            // 2 bytes - key length
            // n bytes - key
            let namedGroup = TLSNamedGroup(rawValue: rawBody[offset...].uInt16)
            offset += 2
            let keySize = rawBody[offset...].uInt16
            offset += 2
            let keyRange = offset..<(offset + Int(keySize))
            let key = rawBody[keyRange]
            offset += Int(keySize)
            if let namedGroup {
                keys.append(TLSKeyShare(namedGroup: namedGroup, key: key))
            }
        }
        
        self.keyShares = keys
    }
}
