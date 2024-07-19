//
//  DigestAuthentication.swift
//
//
//  Created by Tomasz Kucharski on 19/07/2024.
//

import Foundation

public class DigestAuthentication {
    // String describing the service
    let realm: String
    // credentials provider returns password for user
    let credentialsProvider: (String) -> String?
    
    public init(realm: String, credentialsProvider: @escaping (String) -> String?) {
        self.realm = realm
        self.credentialsProvider = credentialsProvider
    }
    
    private func generateChallenge(_ request: HttpRequest) -> HttpInstantResponse {
        let responseHeaders = HttpResponseHeaders()
        let challenge = [
            "Digest realm=\"\(realm)\"",
            "qop=\"auth\"",
            "nonce=\"\(request.id.uuidString.utf8.md5)\"",
            "opaque=\"\(Date().description.utf8.md5)\""
        ]

        responseHeaders.addHeader("WWW-Authenticate", challenge.joined(separator: ", "))
        return HttpInstantResponse(response: .unauthorized(.text("Please authenticate")), headers: responseHeaders)
    }

    public func authorizedUser(_ request: HttpRequest) throws -> String {
        
        if let authorization = request.headers.get("Authorization") {

            var values: [String: String] = [:]
            authorization.split(",").forEach { line in
                guard let equalSignIndex = line.firstIndex(of: "=") else { return }
                let key = String(line.prefix(upTo: equalSignIndex)).trimmed
                let value = String(line.suffix(from: equalSignIndex).dropFirst()).trimming("\"")
                values[key] = value
            }
            guard values["realm"] == realm else {
                throw HttpInstantResponse(response: .badRequest(.text("realm mismatch")))
            }
            guard let uri = values["uri"], uri.starts(with: request.path) else {
                throw HttpInstantResponse(response: .badRequest(.text("uri mismatch")))
            }
            guard let username = values["Digest username"] else {
                throw HttpInstantResponse(response: .badRequest(.text("no username")))
            }
            guard let serverNonce = values["nonce"], let clientNonce = values["cnonce"], 
                    let counter = values["nc"], let qualityOfProtection = values["qop"] else {
                throw HttpInstantResponse(response: .badRequest(.text("missing authorization values")))
            }
            guard let password = credentialsProvider(username) else {
                throw generateChallenge(request)
            }
            let ha1 = "\(username):\(realm):\(password)".utf8.md5
            let ha2 = "\(request.method.rawValue):\(uri)".utf8.md5
            let response = "\(ha1):\(serverNonce):\(counter):\(clientNonce):\(qualityOfProtection):\(ha2)".utf8.md5
            if response.rawValue == values["response"] {
                return username
            }
        }
        throw generateChallenge(request)
    }
}
