//
//  TLSRecordFactory.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//
import Foundation
import SwiftExtensions

enum TLSRecordFactoryError: Error {
    case unknownRecordType
    case unknownRecordVersion
    case unsupportedRecordType(TLSRecordType)
    case unknownHandshakeType
    case unsupportedHandshakeType(TLSHandshakeType)
    case unknownMessageVersion(String)
    case invalidCipherLength(UInt16)
}

enum TLSRecordFactory {
    static func parse(stream: TLSStream) throws -> TLSRecord {
        guard let recordType = try TLSRecordType(rawValue: stream.read()) else {
            throw TLSRecordFactoryError.unknownRecordType
        }
        guard let version = TLSVersion(rawValue: try stream.readUInt16()) else {
            throw TLSRecordFactoryError.unknownRecordVersion
        }
        let length = try stream.readUInt16()
        
        switch recordType {
        case .changeCipherSpec:
            throw TLSRecordFactoryError.unsupportedRecordType(recordType)
        case .alert:
            return TLSRecord(recordType: recordType,
                             version: version,
                             body: try Self.assembleAlert(stream: stream))
        case .handshake:
            return TLSRecord(recordType: recordType,
                             version: version,
                             body: try Self.assembleHandshake(stream: stream, frameLength: length))
        case .applicationData:
            throw TLSRecordFactoryError.unsupportedRecordType(recordType)
        }
    }
    
    private static func assembleAlert(stream: TLSStream) throws -> TLSAlert {
        TLSAlert(rawLevel: try stream.read(), rawCause: try stream.read())
    }
    
    private static func assembleHandshake(stream: TLSStream, frameLength: UInt16) throws -> TLSRecordBody {
        guard let handshakeType = TLSHandshakeType(rawValue: try stream.read()) else {
            throw TLSRecordFactoryError.unknownHandshakeType
        }
        switch handshakeType {
        case .helloRequest:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .clientHello:
            return try Self.assembleClientHello(stream: stream)
        case .serverHello:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .certificate:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .certificateRequest:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .certificateVerify:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .finished:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .newSessionTicket:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .endOfEarlyData:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .helloRetryRequest:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .encryptedExtensions:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .keyUpdate:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        case .messageHash:
            throw TLSRecordFactoryError.unsupportedHandshakeType(handshakeType)
        }
        
    }
    
    private static func assembleClientHello(stream: TLSStream) throws -> TLSRecordBody {
        let _ = try stream.readUInt24()
        let versionCode = try stream.readUInt16()
        guard let messageVersion = TLSVersion(rawValue: versionCode) else {
            throw TLSRecordFactoryError.unknownMessageVersion(versionCode.hexString)
        }
        let random = try TLSRandom(try stream.read(length: 32))
        let sessionLength = try stream.read()
        let sessionID = sessionLength == 0 ? [] : try stream.read(length: sessionLength)
        let cipherLength = try stream.readUInt16()
        guard cipherLength % 2 == 0 else {
            throw TLSRecordFactoryError.invalidCipherLength(cipherLength)
        }
        var ciphers: [TLSCipherSuite] = []
        for _ in 0..<(cipherLength / 2) {
            if let cipher = TLSCipherSuite(rawValue: try stream.readUInt16()) { ciphers.append(cipher) }
        }
        
        var compressionMethods: [TLSCompressionMethod] = []
        let compressionLength = try stream.read()
        if compressionLength > 0 {
            compressionMethods = try (0..<compressionLength).compactMap { _ in TLSCompressionMethod(rawValue: try stream.read()) }
        }
        var extensionsLength = try stream.readUInt16()
        var extensions: [TLSExtension] = []
        while extensionsLength > 0 {
            let extensionCode = try stream.readUInt16()
            let extensionLength = try stream.readUInt16()
            let extensionBody = try stream.read(length: extensionLength)
            extensionsLength -= 4 + extensionLength
            extensions.append(TLSExtension(rawType: extensionCode,
                                           rawBody: extensionBody.data))
        }
        
//        print("sessionID: \(Data(sessionID).hexString)")
//        print("ciphers: \(ciphers.map{$0.string})")
//        print("compressionMethods: \(compressionMethods)")
//        print("extensions: \(extensions)")

        let clientHello = TLSClientHello(legacyVersion: messageVersion,
                                         random: random,
                                         sessionID: sessionID,
                                         supportedCiphers: ciphers,
                                         compressionMethods: compressionMethods,
                                         extensions: extensions)
        return clientHello
    }
}
