//
//  TLSHandler.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import SwiftExtensions
import Foundation
import Crypto

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
        print("IN: \(record) body: \(record.body)")
        guard let clientHello = record.body as? TLSClientHello else {
            print("Expected TLSClientHello but received \(type(of: record.body))")
            try terminateWithAlert(.handshakeFailure)
            return
        }
        
        // what can go wrong:
        // client sends unsupported ciphers
        // client sends keyShare in unsupported group
        // client sends unsupported TLS version
        guard let sharedKeyExtension = (clientHello.extensions.first { $0.type == .keyShare }) else {
            print("Missing preshared key")
            try terminateWithAlert(.missingExtension)
            return
        }
        let sharedKey = try clientHello.extensions.compactMap { try $0.asClientHelloKeyShare }
        print("sharedKey: \(sharedKey)")
        //print("sharedKey: \(sharedKey.key.bytes.chunked(by: 2).map{ $0.data.hexString }.joined(separator: " "))")
        
        let supportedVersions = try clientHello.supportedVersions
        print("supportedVersions: \(supportedVersions)")
        let chosenVersion = supportedVersions.first ?? clientHello.legacyVersion
        print("chosen version: \(chosenVersion)")
        
        let chosenVersionExtension = TLSSupportedVersions(versions: [chosenVersion]).asExtension
        let keyShareExtension = TLSKeyShare(namedGroup: .x25519).asExtension
        
        /*
        let serverKeyPair = Curve25519.KeyAgreement.PrivateKey()
        let serverPublicKey = serverKeyPair.publicKey.rawRepresentation  // 32 bajty
        let serverPrivateKey = serverKeyPair.rawRepresentation
        
        let clientPublicKeyRaw = sharedKey.key
        
        let clientPubKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: clientPublicKeyRaw)
        let sharedSecret = try serverKeyPair.sharedSecretFromKeyAgreement(with: clientPubKey)
        
        let salt = Data(repeating: 0, count: 32) // zależnie od etapu TLS
        let sharedSecretBytes = sharedSecret.withUnsafeBytes { Data($0) }

        print("sharedSecretBytes: \(sharedSecretBytes.hexString)")
//        let prk = HMAC<SHA256>.authenticationCode(for: sharedSecretBytes, using: SymmetricKey(data: salt))
//        let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: prk),
//                                             info: Data("tls13 derived".utf8),
//                                             outputByteCount: 32)
//
//        let aesKey = derived.withUnsafeBytes { Data($0) } // lub SymmetricKey
        */
        let serverHello = TLSServerHello(legacyVersion: .v1_2,
                                         random: try TLSRandom.hrr,
                                         sessionID: clientHello.sessionID,
                                         chosenCipher: .TLS_AES_128_GCM_SHA256,
                                         compressionMethod: .null,
                                         extensions: [keyShareExtension, chosenVersionExtension])
        let response = TLSRecord(recordType: .handshake, version: record.version, body: serverHello)
        print("OUT: \(response.serialised.bytes.map{ $0.data.hexString }.joined(separator: ""))")
        try stream.writeUInt8(response.serialised.bytes)
        let record2 = try TLSRecordFactory.parse(stream: self.stream)
        print("IN: \(record2) body: \(record2.body)")
    }
}
