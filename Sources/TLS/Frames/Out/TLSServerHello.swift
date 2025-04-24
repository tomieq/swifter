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
    let sessionID: [UInt8]
    let chosenCipher: TLSCipherSuite
    let compressionMethod: TLSCompressionMethod
    let extensions: [TLSExtension]
    
    init(version: TLSVersion, random: TLSRandom, sessionID: [UInt8], chosenCipher: TLSCipherSuite, compressionMethod: TLSCompressionMethod, extensions: [TLSExtension]) {
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
        var result = Data([TLSHandshakeType.serverHello.rawValue])
        // message length
        
        var message = TLSVersion.v1_3.rawValue.data
        message.append(contentsOf: random.randomBytes)
        message.append(contentsOf: [UInt8(sessionID.count)])
        message.append(contentsOf: sessionID)
        message.append(chosenCipher.rawValue.data)
        message.append(compressionMethod.rawValue)
        var extensionResult = Data()
//        extensions.filter{ $0.type == .keyShare }.forEach {
//            extensionResult.append($0.serialised)
//        }
        message.append(UInt16(extensionResult.count).data)
        message.append(extensionResult)
        
        result.append(message.count.threeBytes)
        result.append(message)
        return result
    }
}
