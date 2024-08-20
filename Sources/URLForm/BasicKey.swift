//
//  BasicKey.swift
//
//
//  Created by Tomasz on 27/06/2024.
//

import Foundation

public struct BasicKey: CodingKey {

    public init(_ string: String) {
        stringValue = string
    }

    public init(_ int: Int) {
        intValue = int
        stringValue = int.description
    }

    public init?(stringValue: String) {
        self.stringValue = stringValue
    }

    public init?(intValue: Int) {
        self.intValue = intValue
        stringValue = intValue.description
    }

    public var stringValue: String
    public var intValue: Int?
}

public protocol BasicKeyRepresentable {
    func makeBasicKey() -> BasicKey
}

extension String: BasicKeyRepresentable {
    public func makeBasicKey() -> BasicKey {
        BasicKey(self)
    }
}

extension Int: BasicKeyRepresentable {
    public func makeBasicKey() -> BasicKey {
        BasicKey(self)
    }
}

extension Array where Element == BasicKeyRepresentable {
    public func makeBasicKeys() -> [BasicKey] {
        map { $0.makeBasicKey() }
    }
}
