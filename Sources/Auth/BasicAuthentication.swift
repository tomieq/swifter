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
        
        if let authorization = request.headers.get("Authorization"), authorization.starts(with: "Basic") {

            guard let data = authorization.trimming("Basic ").data(using: .utf8),
                  let decoded = Data(base64Encoded: data),
                  let value = String(data: decoded, encoding: .utf8),
                  let colonIndex = value.firstIndex(of: ":") else {
                return nil
            }
            let username = String(value.prefix(upTo: colonIndex)).trimmed
            let password = String(value.suffix(from: colonIndex).dropFirst())
            
            if credentialsProvider(username) == password {
                return username
            }
        }
        return nil
    }
}
