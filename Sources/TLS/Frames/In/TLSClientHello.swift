//
//  TLSClientHello.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//

class TLSClientHello: TLSRecordBody {
    let version: TLSVersion
    let random: TLSRandom
    let sessionID: [UInt8]
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
        self.sessionID = sessionID
        self.supportedCiphers = supportedCiphers
        self.compressionMethods = compressionMethods
        self.extensions = extensions
    }
}

extension TLSClientHello: CustomStringConvertible {
    var description: String {
        "TLSClientHello version: \(version)"
    }
}
