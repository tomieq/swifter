//
//  TLSAlert.swift
//  Swifter
//
//  Created by Tomasz on 24/04/2025.
//
import Foundation

class TLSAlert: TLSRecordBody {
    enum Level: UInt8 {
        case warning = 1
        case fatal = 2
    }
    enum Cause: UInt8 {
        case closeNotify = 0
        case unexpectedMessage = 10
        case badRecordMac = 20
        case decryptionFailed = 21
        case recordOverflow = 22
        case decompressionFailure = 30
        case handshakeFailure = 40
        case badCertificate = 42
        case unsupportedCertificate = 43
        case certificateRevoked = 44
        case certificateExpired = 45
        case certificateUnknown = 46
        case illegalParameter = 47
        case unknownCA = 48
        case accessDenied = 49
        case decodeError = 50
        case decryptError = 51
        case exportRestriction = 60
        case protocolVersion = 70
        case insufficientSecurity = 71
        case internalError = 80
        case userCanceled = 90
        case noRenegotiation = 100
        case missingExtension = 109
        case unsupportedExtension = 110
        case certificateUnobtainable = 111
        case unrecognizedName = 112
        case badCertificateStatusResponse = 113
        case badCertificateHashValue = 114
    }
    let rawLevel: UInt8
    let rawCause: UInt8
    var cause: Cause? {
        Cause(rawValue: rawCause)
    }
    var level: Level? {
        Level(rawValue: rawLevel)
    }
    
    init(rawLevel: UInt8, rawCause: UInt8) {
        self.rawLevel = rawLevel
        self.rawCause = rawCause
    }
    
    init(level: Level, cause: Cause) {
        self.rawLevel = level.rawValue
        self.rawCause = cause.rawValue
    }
}

extension TLSAlert: TLSOutMessage {
    var serialised: Data {
        Data([rawLevel, rawCause])
    }
}

extension TLSAlert: CustomStringConvertible {
    var description: String {
        "\(level?.string ?? rawLevel.hexString): \(cause?.string ?? rawCause.hexString)"
    }
}

extension TLSAlert.Cause {
    var string: String {
        "\(self)".components(separatedBy: ".").last ?? "\(self)"
    }
}
extension TLSAlert.Level {
    var string: String {
        "\(self)".components(separatedBy: ".").last ?? "\(self)"
    }
}
