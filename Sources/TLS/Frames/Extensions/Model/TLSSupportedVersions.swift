//
//  TLSSupportedVersions.swift
//  Swifter
//
//  Created by Tomasz on 25/04/2025.
//
import Foundation
import SwiftExtensions

enum TLSSupportedVersionsError: Error {
    case invalidBytesSize(expected: Int, received: Int)
}

struct TLSSupportedVersions {
    let versions: [TLSVersion]
    
    init(versions: [TLSVersion]) {
        self.versions = versions
    }
    
    init(data: Data) throws {
        guard data.isEmpty.not else {
            versions = []
            return
        }
        let lenght = data.bytes[0]
        
        let expectedLength =  1 + lenght
        guard data.count == expectedLength else {
            throw TLSSupportedVersionsError.invalidBytesSize(expected: Int(expectedLength), received: data.count)
        }
        versions = (0..<lenght/2).compactMap { index in
            let offset = Int(1 + index * 2)
            let bytes = data.bytes[offset...]
            return TLSVersion(rawValue: bytes.array.data.uInt16)
        }
    }
}

extension TLSSupportedVersions: TLSOutMessage {
    var serialised: Data {
        var result = UInt8(1 + versions.count * 2).data
        for version in self.versions {
            result.append(version.rawValue.data)
        }
        return result
    }
}

extension TLSSupportedVersions {
    var asExtension: TLSExtension {
        TLSExtension(type: .supportedVersions, rawBody: serialised)
    }
}
