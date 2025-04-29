//
//  TLSRecord.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import Foundation
import SwiftExtensions

struct TLSRecord {
    let recordType: TLSRecordType
    let version: TLSVersion
    let body: TLSRecordBody
}

extension TLSRecord: CustomStringConvertible {
    var description: String {
        "recordType: \(recordType), version: \(version)"
    }
}

extension TLSRecord: TLSOutMessage {
    var serialised: Data {
        guard let body = self.body as? TLSOutMessage else {
            print("Not serializable body")
            return Data()
        }
        var result = recordType.rawValue.data
            .appending(version.rawValue.data)
        let serialisedBody = body.serialised
        result.append(UInt16(serialisedBody.count).data)
        result.append(serialisedBody)
        return result
    }
}
