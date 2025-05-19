//
//  TLSHandler.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import SwiftExtensions
import Foundation
import Crypto

/*
 TLS 1.3
 >>> ClientHello
 
 ### The TLS version mess
 TLSRecord's version always is set to 1.0
 TLSClientHello's version is always set to 1.2
 The real supported version offered by the client in is the extension TLSSupportedVersion
 
 most clients choose algorithm x25519 for KeyShare extension (Curve25519)
 
 
 
 */
enum TLSHandlerError: Error {
    case notImplemented(String)
}

class TLSHandler {
    private let stream: SocketTracker
    
    init(stream: TLSStream) {
        self.stream = SocketTracker(stream: stream)
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
        print("--------- Incoming connection from \(stream.peerIP ?? "nil")")
        
        let record = try TLSRecordFactory.parse(stream: self.stream)
        print("IN: \(record) body: \(record.body)")
        print("\(stream.inputCache.hexString.chunked(by: 2).joined(separator: " "))")
        guard let clientHello = record.body as? TLSClientHello else {
            print("Expected TLSClientHello but received \(type(of: record.body))")
            try terminateWithAlert(.handshakeFailure)
            return
        }
        print("Incoming extensions: \(clientHello.extensions.compactMap{ $0.type?.string })")
        print("Supported cipher suites: \(clientHello.supportedCiphers.map { $0.string })")
        
        // what can go wrong:
        // client sends unsupported ciphers
        // client sends keyShare with unsupported group
        // client sends unsupported TLS version
        
        /// https://datatracker.ietf.org/doc/html/rfc6066#page-6
        ///  server may response with unrecognizedName
        if let serverName = (try clientHello.extensions.compactMap{ try $0.asServerName }.first) {
            //try terminateWithAlert(.unrecognizedName)
            print("serverName: \(serverName.first?.serverName ?? "nil")")
        }
        

        let sharedKey = try clientHello.extensions.compactMap { try $0.asClientHelloKeyShare }
        print("sharedKey: \(sharedKey)")
        //print("sharedKey: \(sharedKey.key.bytes.chunked(by: 2).map{ $0.data.hexString }.joined(separator: " "))")
        
        let supportedVersions = try clientHello.extensions.compactMap{ try $0.asSupportedVersions }.first
        print("supportedVersions: \(supportedVersions ?? [])")
        
        let serverKeyPair = Curve25519.KeyAgreement.PrivateKey()
        let serverPublicKey = serverKeyPair.publicKey.rawRepresentation  // 32 bajty
        let serverPrivateKey = serverKeyPair.rawRepresentation
        /*
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
        
        let supportedVersionExtension = TLSExtension(type: .supportedVersions,
                                                     rawBody: TLSVersion.v1_3.rawValue.data)
        let keyShareExtension = TLSKeyShare(namedGroup: .x25519,
                                            key: serverPublicKey).asExtension
        let serverHello = TLSServerHello(legacyVersion: .v1_2,
                                         random: clientHello.random,//try TLSRandom.hrr,
                                         sessionID: clientHello.sessionID,
                                         chosenCipher: .TLS_AES_128_GCM_SHA256,
                                         compressionMethod: .null,
                                         extensions: [
                                            supportedVersionExtension,
                                            keyShareExtension
                                         ])
        let serverHelloRecord = TLSRecord(recordType: .handshake, version: record.version, body: serverHello)
        try stream.writeUInt8(serverHelloRecord.serialised.bytes)
        
        let changeCipherSpecRecord = TLSRecord(recordType: .changeCipherSpec, version: .v1_2, body: TLSChangeCipherSpec())
        try stream.writeUInt8(changeCipherSpecRecord.serialised.bytes)
        
//        print("\(stream.outputCache.hexString.chunked(by: 2).joined(separator: " "))")
//        print("\(stream.outputCache.hexString)")
        stream.close()
        let record2 = try TLSRecordFactory.parse(stream: self.stream)
        print("IN: \(record2) body: \(record2.body)")
    }
}
