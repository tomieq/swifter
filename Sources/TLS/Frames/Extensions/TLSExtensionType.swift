//
//  TLSExtensionType.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//

enum TLSExtensionType: UInt16 {
    case serverName = 0
    case statusRequest = 0x05
    case supportedGroups = 0x0A
    case ecPointFormats = 0x0B  // TLS 1.2 only, not in TLS 1.3
    case signatureAlgorithms = 0x0D
    case applicationLayerProtocolNegotiation = 0x10
    case signedCertificateTimestamp = 0x12
    case preSharedKey = 0x29
    case earlyData = 0x2A
    case supportedVersions = 0x2B
    case cookie = 0x2C
    case pskKeyExchangeModes = 0x2D
    case certificateAuthorities = 0x2F
    case oidFilters = 0x30
    case postHandshakeAuth = 0x31
    case signatureAlgorithmsCert = 0x32
    case keyShare = 0x33
    
    case secureRenegotiationInfo = 0xff01
}

extension TLSExtensionType {
    var string: String {
        "\(self)".components(separatedBy: ".").last ?? "\(self)"
    }
}
