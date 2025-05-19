//
//  TLSExtension+TLSNamedGroup.swift
//  Swifter
//
//  Created by Tomasz on 19/05/2025.
//

import Foundation

extension TLSExtension {
    var asSupportedGroups: [TLSNamedGroup]? {
        get throws {
            guard self.type == .supportedGroups else { return nil }
            return try TLSNamedGroupFactory(rawBody: rawBody).supportedGroups
        }
    }
}

enum TLSNamedGroupFactoryError: Error {
    case invalidBytesSize(expected: Int, received: Int)
}

fileprivate class TLSNamedGroupFactory {
    let supportedGroups: [TLSNamedGroup]
    
    init(rawBody: Data) throws {
        guard rawBody.isEmpty.not else {
            supportedGroups = []
            return
        }
        var rawBody = rawBody
        var groups: [TLSNamedGroup] = []
        while rawBody.isEmpty.not {
            if let group = TLSNamedGroup(rawValue: try rawBody.consume(bytes: 2).uInt16) {
                groups.append(group)
            }
        }
        supportedGroups = groups
    }
}
