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
    case unsupportedTransferEncoding
    case uriTooLong
    case headersTooLarge
    case invalidChunkSize(String)
    case bodyTooLarge(Int)
}

public enum RequestBodyLimit {
    case unlimited
    case limit(DataSize)
}

public class HttpParser {
    private let bodyLimit: RequestBodyLimit
    private let maxHeadersCount: Int

    public init(bodyLimit: RequestBodyLimit, maxHeadersCount: Int = 100) {
        self.bodyLimit = bodyLimit
        self.maxHeadersCount = maxHeadersCount
    }

    public func readHttpRequest(_ socket: SecureSocket) async throws -> HttpRequest {
        let statusLine: String
        do {
            statusLine = try await socket.readLine()
        } catch SocketError.lineTooLong {
            throw HttpParserError.uriTooLong
        }
        let statusLineTokens = statusLine.components(separatedBy: " ")
        if statusLineTokens.count < 3 {
            throw HttpParserError.invalidStatusLine(statusLine)
        }
        let request = HttpRequest(socketID: socket.id)
        request.clientIP = socket.peerIP
        request.method = HttpMethod(statusLineTokens[0]) ?? .unknown
        let encodedPath = self.escapingInvalidURL(statusLineTokens[1])
        let urlComponents = URLComponents(string: encodedPath)
        request.path = urlComponents?.path ?? ""
        request.queryParams = HttpRequestParams(urlComponents?.queryItems?.map { ($0.name, $0.value ?? "") })
        request.headers = HttpRequestHeaderParams(try await self.readHeaders(socket))
        request.headers[.cookie]?.split(";")
            .map{ $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.split("=") }
            .forEach { data in
                if data.count > 1 {
                    request.cookies.storage.append((data[0], data[1]))
                }
            }

        if let transferEncoding = request.headers[.transferEncoding] {
            guard self.usesChunkedTransferEncoding(transferEncoding) else {
                throw HttpParserError.unsupportedTransferEncoding
            }
            do {
                let bodyBytes = try await self.readChunkedBody(socket)
                request.body = HttpRequestBody(bodyBytes)
            } catch HttpParserError.bodyTooLarge(let total) {
                request.body = HttpRequestBody([], status: .exceededLimit(bodySize: DataSize(total)))
            }
        } else if let contentLength = request.headers[.contentLength], let contentLengthValue = Int(contentLength), contentLengthValue >= 0 {
            if case .limit(let dataSize) = bodyLimit, dataSize.count < contentLengthValue {
                let msg = "Incoming body size \(DataSize(contentLengthValue)) exceeds current server \(bodyLimit)"
                print(msg)
                request.body = HttpRequestBody([], status: .exceededLimit(bodySize: DataSize(contentLengthValue)))
            } else {
                request.body = HttpRequestBody(try await self.readBody(socket, size: contentLengthValue))
            }
        }
        return request
    }

    public func readHttpRequestAsync(_ socket: SecureSocket) async throws -> HttpRequest {
        try await self.readHttpRequest(socket)
    }

    private func usesChunkedTransferEncoding(_ transferEncoding: String) -> Bool {
        let tokens = transferEncoding
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        return tokens.count == 1 && tokens.first == "chunked"
    }

    /// Read a chunked transfer-encoding body from the socket.
    /// Implements RFC 7230 §4.1 chunked encoding: each chunk begins with
    /// a hex length, optional extensions, CRLF, data, CRLF. A zero-length
    /// chunk signals the end, optionally followed by trailer headers and
    /// a final CRLF.
    private func readChunkedBody(_ socket: SecureSocket) async throws -> [UInt8] {
        var result = [UInt8]()
        while true {
            let sizeLine: String
            do {
                sizeLine = try await socket.readLine().trimmingCharacters(in: .whitespaces)
            } catch SocketError.lineTooLong {
                throw HttpParserError.headersTooLarge
            }
            let hexPart = sizeLine.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
            guard let chunkSize = Int(hexPart, radix: 16) else {
                throw HttpParserError.invalidChunkSize(sizeLine)
            }
            if chunkSize == 0 {
                _ = try await self.readHeaders(socket)
                break
            }

            try self.checkBodyLimit(currentSize: result.count, nextChunkSize: chunkSize)
            let chunk = try await socket.read(length: chunkSize)
            result.append(contentsOf: chunk)

            let cr = try await socket.read()
            let nl = try await socket.read()
            if cr != 13 || nl != 10 {
                throw HttpParserError.invalidChunkSize(sizeLine)
            }
        }
        return result
    }

    private func readChunkedBodyAsync(_ socket: SecureSocket) async throws -> [UInt8] {
        try await self.readChunkedBody(socket)
    }

    private func checkBodyLimit(currentSize: Int, nextChunkSize: Int) throws {
        guard case .limit(let dataSize) = bodyLimit else { return }
        if nextChunkSize > dataSize.count - currentSize {
            throw HttpParserError.bodyTooLarge(currentSize + nextChunkSize)
        }
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

    private func readBody(_ socket: SecureSocket, size: Int) async throws -> [UInt8] {
        try await socket.read(length: size)
    }

    private func readBodyAsync(_ socket: SecureSocket, size: Int) async throws -> [UInt8] {
        try await self.readBody(socket, size: size)
    }

    private func readHeaders(_ socket: SecureSocket) async throws -> [String: String] {
        var headers = [String: String]()
        var headerCount = 0
        while true {
            let headerLine: String
            do {
                headerLine = try await socket.readLine()
            } catch SocketError.lineTooLong {
                throw HttpParserError.headersTooLarge
            }
            headerCount += 1
            if headerCount > self.maxHeadersCount {
                throw HttpParserError.headersTooLarge
            }
            if headerLine.isEmpty { break }
            let headerTokens = headerLine.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            if let name = headerTokens.first, let value = headerTokens.last {
                headers[name.lowercased()] = value.trimmingCharacters(in: .whitespaces)
            }
        }
        return headers
    }

    private func readHeadersAsync(_ socket: SecureSocket) async throws -> [String: String] {
        try await self.readHeaders(socket)
    }
}
