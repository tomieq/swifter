//
//  TLSAlert.swift
//  Swifter
//
//  Created by Tomasz on 24/04/2025.
//
import Foundation

class TLSAlert: TLSRecordBody {
    let message: String

    init(message: String) {
        self.message = message
    }
}

extension TLSAlert: TLSOutMessage {
    var serialised: Data {
        message.data(using: .utf8) ?? Data()
    }
}
