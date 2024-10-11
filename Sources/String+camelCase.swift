//
//  String+camelCase.swift
//
//
//  Created by Tomasz on 28/06/2024.
//

import Foundation

extension String {
    public var lowercasingFirst: String { prefix(1).lowercased() + dropFirst() }
    public var uppercasingFirst: String { prefix(1).uppercased() + dropFirst() }

    public var camelCased: String {
        guard !isEmpty else { return "" }
        let parts = components(separatedBy: .alphanumerics.inverted)
        let first = parts.first!.lowercasingFirst
        let rest = parts.dropFirst().map { $0.uppercasingFirst }

        return ([first] + rest).joined()
    }
}
