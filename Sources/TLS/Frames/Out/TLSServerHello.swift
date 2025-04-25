//
//  TLSServerHello.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import Foundation
import SwiftExtensions

class TLSServerHello: TLSRecordBody {
    let version: TLSVersion
    let random: TLSRandom
    let sessionID: Data
    let chosenCipher: TLSCipherSuite
    let compressionMethod: TLSCompressionMethod
    let extensions: [TLSExtension]
    
    init(version: TLSVersion, random: TLSRandom, sessionID: Data, chosenCipher: TLSCipherSuite, compressionMethod: TLSCompressionMethod, extensions: [TLSExtension]) {
        self.version = version
        self.random = random
        self.sessionID = sessionID
        self.chosenCipher = chosenCipher
        self.compressionMethod = compressionMethod
        self.extensions = extensions
    }
}

extension TLSServerHello: TLSOutMessage {
    var serialised: Data {
        
        var extensionResult = Data()
        extensions.filter{ $0.type == .keyShare }.forEach {
            extensionResult.append($0.serialised)
        }
        
        let message = TLSVersion.v1_3.rawValue.data
            .appending(random.randomBytes)
            .appending(UInt8(sessionID.count).data)
            .appending(sessionID)
            .appending(chosenCipher.rawValue.data)
            .appending(compressionMethod.rawValue.data)
            .appending(UInt16(extensionResult.count).data)
            .appending(extensionResult)
        
        let result = TLSHandshakeType.serverHello.rawValue.data
            .appending(message.count.threeBytes)
            .appending(message)
        return result
    }
}
