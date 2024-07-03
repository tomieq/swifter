//
//  HttpParser.swift
//  Swifter
// 
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

enum HttpParserError: Error, Equatable {
    case invalidStatusLine(String)
    case negativeContentLength
}

public class HttpParser {

    public init() { }

    public func readHttpRequest(_ socket: Socket) throws -> HttpRequest {
        let statusLine = try socket.readLine()
        let statusLineTokens = statusLine.components(separatedBy: " ")
        if statusLineTokens.count < 3 {
            throw HttpParserError.invalidStatusLine(statusLine)
        }
        let request = HttpRequest()
        request.peerName = try? socket.peername()
        request.method = HttpMethod(statusLineTokens[0]) ?? .unknown
        let encodedPath = self.escapingInvalidURL(statusLineTokens[1])
        let urlComponents = URLComponents(string: encodedPath)
        request.path = urlComponents?.path ?? ""
        request.queryParams = HttpRequestParams(urlComponents?.queryItems?.map { ($0.name, $0.value ?? "") })
        request.headers = HttpRequestParams(try readHeaders(socket))
        request.headers["cookie"]?.split(";")
            .map{ $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.split("=") }
            .forEach { data in
                if data.count > 1 {
                    request.cookies.storage.append((data[0], data[1]))
                }
            }
        
        if let contentLength = request.headers["content-length"], let contentLengthValue = Int(contentLength) {
            // Prevent a buffer overflow and runtime error trying to create an `UnsafeMutableBufferPointer` with
            // a negative length
            guard contentLengthValue >= 0 else {
                throw HttpParserError.negativeContentLength
            }
            request.body = HttpRequestBody(try readBody(socket, size: contentLengthValue))
        }
        return request
    }
    /// only escaping invalid chars，valid encodedPath keep untouched
    private func escapingInvalidURL(_ url: String) -> String {
        var urlAllowed: CharacterSet {
            var allow = CharacterSet.urlQueryAllowed
            allow.insert(charactersIn: "?#%")
            return allow
        }
        return url.addingPercentEncoding(withAllowedCharacters: urlAllowed) ?? url
    }

    private func readBody(_ socket: Socket, size: Int) throws -> [UInt8] {
        return try socket.read(length: size)
    }

    private func readHeaders(_ socket: Socket) throws -> [String: String] {
        var headers = [String: String]()
        while case let headerLine = try socket.readLine(), !headerLine.isEmpty {
            let headerTokens = headerLine.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            if let name = headerTokens.first, let value = headerTokens.last {
                headers[name.lowercased()] = value.trimmingCharacters(in: .whitespaces)
            }
        }
        return headers
    }
}
