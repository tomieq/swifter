//
//  String+trimming.swift
//
//
//  Created by Tomasz Kucharski on 19/07/2024.
//

import Foundation

extension String {
    func trimming(_ characters: String) -> String {
        return self.trimmingCharacters(in: CharacterSet(charactersIn: characters))
    }

    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
