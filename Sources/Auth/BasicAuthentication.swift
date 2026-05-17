//
//  BasicAuthentication.swift
//
//
//  Created by Tomasz Kucharski on 19/07/2024.
//

import Foundation

public class BasicAuthentication {
    // credentials provider returns password for user
    let credentialsProvider: (String) -> String?

    public init(credentialsProvider: @escaping (String) -> String?) {
        self.credentialsProvider = credentialsProvider
    }

    public func authorizedUser(_ request: HttpRequest) -> String? {
        if let authorization = request.headers[.authorization] {
            // Expect header like: Basic base64(username:password)
            let header = authorization.trimmingCharacters(in: .whitespacesAndNewlines)
            guard header.count > 6 else { return nil }
            let prefix = String(header.prefix(6))
            guard prefix.lowercased() == "basic " else { return nil }

            let base64Part = header.dropFirst(6).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let decodedData = Data(base64Encoded: String(base64Part)),
                  let credentials = String(data: decodedData, encoding: .utf8) else {
                return nil
            }

            let parts = credentials.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let username = String(parts[0]).trimmed
            let password = String(parts[1])

            if let expected = self.credentialsProvider(username), timingSafeEqual(expected, password) {
                return username
            }
        }
        return nil
    }
}
