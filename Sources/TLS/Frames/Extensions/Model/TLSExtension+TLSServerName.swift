//
//  TLSExtension+TLSServerName.swift
//  Swifter
//
//  Created by Tomasz on 15/05/2025.
//
import Foundation

extension TLSExtension {
    var asServerName: [TLSServerName]? {
        get throws {
            guard self.type == .serverName else { return nil }
            return try TLSServerNameFactory(rawBody: rawBody).serverNames
        }
    }
}

fileprivate class TLSServerNameFactory {
    let serverNames: [TLSServerName]
    
    init(rawBody: Data) throws {
        var names: [TLSServerName] = []
        var rawBody = rawBody
        
        let bodyLenght = try rawBody.consume(bytes: 2).uInt16
        guard bodyLenght > 3 else {
            throw TLSKeyShareFactoryError.invalidByteCount
        }
        while rawBody.isEmpty.not {
            // 2 bytes - name type
            // 1 byte - name length
            // n bytes - name
            let nameType = TLSServerNameType(rawValue: try rawBody.consume(bytes: 2).uInt16)
            let nameSize = try rawBody.consume(bytes: 1).uInt8
            let name = String(data: rawBody.consume(bytes: Int(nameSize)), encoding: .utf8)
            if let nameType, let name {
                names.append(TLSServerName(nameType: nameType, serverName: name))
            }
        }
        self.serverNames = names
    }
}
