//
//  URLFormError.swift
//
//
//  Created by Tomasz on 27/06/2024.
//

import Foundation

public struct URLFormError: Error {
    public let identifier: String

    public let reason: String

    public init(identifier: String, reason: String) {
        self.identifier = identifier
        self.reason = reason
    }
}
