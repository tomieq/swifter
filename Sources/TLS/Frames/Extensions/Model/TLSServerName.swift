//
//  TLSServerName.swift
//  Swifter
//
//  Created by Tomasz on 14/05/2025.
//

/// SNI [https://www.cloudflare.com/pl-pl/learning/ssl/what-is-sni/]
///

struct TLSServerName {
    let nameType: TLSServerNameType
    let serverName: String
}

enum TLSServerNameType: UInt16 {
    case hostname = 0
}
