//
//  TLSKeyShare.swift
//  Swifter
//
//  Created by Tomasz on 25/04/2025.
//
import Foundation


extension TLSExtension {
    var asClientHelloKeyShare: [TLSKeyShare]? {
        get throws {
            guard self.type == .keyShare else { return nil }
            var result: [TLSKeyShare] = []
            var bytesToConsume = rawBody.uInt16
            var offset = 2
            while offset < rawBody.count {
                let keyShare = try TLSKeyShare(rawBytes: rawBody.bytes.subArray(offset...).data)
                offset += keyShare.consumedBytes
                result.append(keyShare)
            }
            return result
        }
    }
}

enum TLSKeyShareError: Error {
    case invalidByteCount
}

enum TLSKeyShareBody {
    case clientHello(clientShares : [TLSKeyShare])
    case helloRetryRequest(selectedGroup: TLSNamedGroup)
    case serverHello(serverShare: TLSKeyShare)
}

struct TLSKeyShare {
    let rawNamedGroup: UInt16
    let namedGroup: TLSNamedGroup?
    let key: Data
    
    var consumedBytes: Int {
        4 + key.count
    }

    init(rawBytes: Data) throws {
        guard rawBytes.count > 2 else {
            throw TLSKeyShareError.invalidByteCount
        }
        rawNamedGroup = rawBytes.uInt16
        namedGroup = TLSNamedGroup(rawValue: rawNamedGroup)
        let keySize = rawBytes.bytes.subArray(2...).data.uInt16
        let keyRange = 4..<(4 + Int(keySize))
        key = rawBytes.bytes.subArray(keyRange).data
    }
    
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
