//
//  TLSExtension+TLSVersion.swift
//  Swifter
//
//  Created by Tomasz on 16/05/2025.
//

import Foundation

extension TLSExtension {
    var asSupportedVersions: [TLSVersion]? {
        get throws {
            guard self.type == .supportedVersions else { return nil }
            return try TLSSupportedVersionFactory(rawBody: rawBody).supportedVersions
        }
    }
}

enum TLSSupportedVersionFactoryError: Error {
    case invalidBytesSize(expected: Int, received: Int)
}

fileprivate class TLSSupportedVersionFactory {
    let supportedVersions: [TLSVersion]
    
    init(rawBody: Data) throws {
        guard rawBody.isEmpty.not else {
            supportedVersions = []
            return
        }
        var rawBody = rawBody
        let lenght = try rawBody.consume(bytes: 1).uInt8
        
        guard rawBody.count == lenght else {
            throw TLSSupportedVersionFactoryError.invalidBytesSize(expected: Int(lenght), received: rawBody.count)
        }
        var versions: [TLSVersion] = []
        while rawBody.isEmpty.not {
            if let version = TLSVersion(rawValue: try rawBody.consume(bytes: 2).uInt16) {
                versions.append(version)
            }
        }
        supportedVersions = versions
    }
}
