//
//  HttpResponsePacket.swift
//  Swifter
//
//  Created by Tomasz Kucharski on 23/07/2025.
//

enum HttpConnectionContinuation {
    case keepAlive
    case closeConection
    
    var keepSocketOpen: Bool {
        switch self {
        case .keepAlive:
            return true
        case .closeConection:
            return false
        }
    }
}

struct HttpResponsePacket {
    let rawBody: HttpResponseBodyRaw?
    let connection: HttpConnectionContinuation
}
