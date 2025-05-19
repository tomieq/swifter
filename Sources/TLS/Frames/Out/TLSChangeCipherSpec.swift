//
//  TLSChangeCipherSpec.swift
//  Swifter
//
//  Created by Tomasz on 19/05/2025.
//

import Foundation
import SwiftExtensions

class TLSChangeCipherSpec: TLSRecordBody {
    let irrelevantByte = Data([0x01])
}

extension TLSChangeCipherSpec: TLSOutMessage {
    var serialised: Data {
        irrelevantByte
    }
}
