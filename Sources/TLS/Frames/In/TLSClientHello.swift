//
//  TLSClientHello.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import Foundation

class TLSClientHello: TLSRecordBody {
    let version: TLSVersion
    let random: TLSRandom
    let sessionID: Data
    let supportedCiphers: [TLSCipherSuite]
    let compressionMethods: [TLSCompressionMethod]
    let extensions: [TLSExtension]
    
    init(version: TLSVersion,
         random: TLSRandom,
         sessionID: [UInt8],
         supportedCiphers: [TLSCipherSuite],
         compressionMethods: [TLSCompressionMethod],
         extensions: [TLSExtension]) {
        self.version = version
        self.random = random
        self.sessionID = sessionID.data
        self.supportedCiphers = supportedCiphers
        self.compressionMethods = compressionMethods
        self.extensions = extensions
    }
}

// MARK: parsed TLSExtensions
extension TLSClientHello {
    var supportedVersions: [TLSVersion] {
        get throws {
            try extensions.filter {
                $0.type == .supportedVersions
            }
            .map { try TLSSupportedVersions(bytes: $0.rawBody).versions }
            .first ?? []
        }
    }
}

extension TLSClientHello: CustomStringConvertible {
    var description: String {
        "TLSClientHello version: \(version)"
    }
}
