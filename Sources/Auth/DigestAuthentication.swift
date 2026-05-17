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
        if let authorization = request.headers[.authorization] {
            let header = authorization.trimmingCharacters(in: .whitespacesAndNewlines)
            guard header.count > 6 else { throw self.generateChallenge(request) }
            let prefix = String(header.prefix(6)).lowercased()
            guard prefix == "digest" || prefix == "digest " else { throw self.generateChallenge(request) }

            // Remove "Digest" prefix.
            let paramsPart = header.dropFirst(6).trimmingCharacters(in: .whitespaces)

            // Parse parameters like key="value" or key=value, commas separate, values may contain escaped quotes.
            var values: [String: String] = [:]
            var scanner = paramsPart[...]
            while !scanner.isEmpty {
                // Extract key
                guard let eqIndex = scanner.firstIndex(of: "=") else { break }
                let key = scanner.prefix(upTo: eqIndex).trimmingCharacters(in: .whitespacesAndNewlines)
                scanner = scanner.suffix(from: scanner.index(after: eqIndex))

                var value = ""
                if scanner.first == "\"" {
                    // Quoted value
                    scanner = scanner.dropFirst()
                    while !scanner.isEmpty {
                        if scanner.first == "\"" {
                            scanner = scanner.dropFirst()
                            break
                        }
                        // handle escaped quotes
                        if scanner.first == "\\" {
                            scanner = scanner.dropFirst()
                            if let c = scanner.first {
                                value.append(c)
                                scanner = scanner.dropFirst()
                            }
                        } else {
                            value.append(scanner.first!)
                            scanner = scanner.dropFirst()
                        }
                    }
                } else {
                    // Token value until comma or end
                    if let commaIndex = scanner.firstIndex(of: ",") {
                        value = String(scanner.prefix(upTo: commaIndex)).trimmingCharacters(in: .whitespacesAndNewlines)
                        scanner = scanner.suffix(from: scanner.index(after: commaIndex))
                    } else {
                        value = String(scanner).trimmingCharacters(in: .whitespacesAndNewlines)
                        scanner = scanner.dropFirst(scanner.count)
                    }
                }

                values[key] = value

                // Drop leading commas and whitespace
                while scanner.first == "," || scanner.first == " " { scanner = scanner.dropFirst() }
            }

            guard values["realm"] == self.realm else {
                throw HttpInstantResponse(response: .unauthorized(.text("realm mismatch")))
            }
            guard let uri = values["uri"], uri.starts(with: request.path) else {
                throw HttpInstantResponse(response: .unauthorized(.text("uri mismatch")))
            }
            guard let username = values["username"] else {
                throw HttpInstantResponse(response: .unauthorized(.text("no username")))
            }
            guard let serverNonce = values["nonce"], let clientNonce = values["cnonce"],
                  let counter = values["nc"], let qualityOfProtection = values["qop"], let responseValue = values["response"] else {
                throw HttpInstantResponse(response: .unauthorized(.text("missing authorization values")))
            }
            guard let password = credentialsProvider(username) else {
                throw self.generateChallenge(request)
            }

            let ha1 = "\(username):\(realm):\(password)".utf8.md5.rawValue
            let ha2 = "\(request.method.rawValue):\(uri)".utf8.md5.rawValue
            let combined = "\(ha1):\(serverNonce):\(counter):\(clientNonce):\(qualityOfProtection):\(ha2)"
            let expected = Array(combined.utf8).md5.rawValue
            if timingSafeEqual(expected, responseValue) {
                return username
            }
        }
        throw self.generateChallenge(request)
    }
}
