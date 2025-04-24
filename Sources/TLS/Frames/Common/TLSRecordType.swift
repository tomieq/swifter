//
//  TLSRecordType.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//

enum TLSRecordType: UInt8 {
    case changeCipherSpec = 0x14
    case alert = 0x15
    case handshake = 0x16
    case applicationData = 0x17
}

extension TLSRecordType: CustomStringConvertible {
    var description: String {
        switch self {
        case .changeCipherSpec:
            "ChangeCipherSpec"
        case .alert:
            "Alert"
        case .handshake:
            "Handshake"
        case .applicationData:
            "ApplicationData"
        }
    }
}
