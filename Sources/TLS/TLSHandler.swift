//
//  TLSHandler.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import SwiftExtensions
import Foundation

enum TLSHandlerError: Error {
    case notImplemented(String)
}

class TLSHandler {
    private let stream: TLSStream
    
    init(stream: TLSStream) {
        self.stream = stream
        do {
            try setup()
        } catch {
            print("Error: \(error)")
            stream.close()
        }
        
    }
    
    private func terminateWithAlert(_ cause: TLSAlert.Cause) throws {
        let alert = TLSAlert(level: .fatal, cause: cause)
        let alertResponse = TLSRecord(recordType: .alert, version: .v1_0, body: alert)
        try stream.writeUInt8(alertResponse.serialised.bytes)
        stream.close()
    }
    
    private func setup() throws {
        print("--------- Incoming connection")
        
        let record = try TLSRecordFactory.parse(stream: self.stream)
        print("\(record) body: \(record.body)")
        guard let clientHello = record.body as? TLSClientHello else {
            print("Expected TLSClientHello but received \(type(of: record.body))")
            try terminateWithAlert(.handshakeFailure)
            return
        }
        guard let sharedKey = (clientHello.extensions.first { $0.type == .keyShare }) else {
            print("Missing preshared key")
            try terminateWithAlert(.missingExtension)
            return
        }
        print("supportedVersions: \(try clientHello.supportedVersions)")
        let serverHello = TLSServerHello(version: .v1_2,
                                         random: clientHello.random,
                                         sessionID: clientHello.sessionID,
                                         chosenCipher: .TLS_AES_128_GCM_SHA256,
                                         compressionMethod: .null,
                                         extensions: clientHello.extensions)
        let response = TLSRecord(recordType: .handshake, version: record.version, body: serverHello)
        try stream.writeUInt8(response.serialised.bytes)
        let record2 = try TLSRecordFactory.parse(stream: self.stream)
        print("\(record2) body: \(record2.body)")
    }
}
