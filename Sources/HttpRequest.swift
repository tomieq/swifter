//
//  HttpRequest.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public enum HttpRequestError: Error {
    case invalidString
}

public class HttpRequest {

    public var peerName: String?
    public var id = UUID()
    public var path: String = ""
    public var queryParams: [(String, String)] = []
    public var method: HttpMethod = .unknown
    public var headers: [String: String] = [:]
    public var cookies: [String: String] = [:]
    public var body: [UInt8] = []
    public var address: String? = ""
    public var pathParams: [String: String] = [:]
    public var disableKeepAlive: Bool = false
    public var onFinished: ((UUID, Int) -> Void)?
    var responseCode: Int?

    public init() {}
    deinit {
        self.onFinished?(self.id, self.responseCode ?? 0)
    }

    public func hasTokenForHeader(_ headerName: String, token: String) -> Bool {
        guard let headerValue = headers[headerName] else {
            return false
        }
        return headerValue.components(separatedBy: ",").filter({ $0.trimmingCharacters(in: .whitespaces).lowercased() == token }).count > 0
    }

    public func parseUrlencodedForm() -> [(String, String)] {
        guard let contentTypeHeader = headers["content-type"] else {
            return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let contentType = contentTypeHeaderTokens.first, contentType == "application/x-www-form-urlencoded" else {
            return []
        }
        guard let utf8String = String(bytes: body, encoding: .utf8) else {
            // Consider to throw an exception here (examine the encoding from headers).
            return []
        }
        return utf8String.components(separatedBy: "&").compactMap { param -> (String, String)? in
            let tokens = param.components(separatedBy: "=")
            if let name = tokens.first?.removingPercentEncoding, let value = tokens.last?.removingPercentEncoding, tokens.count == 2 {
                return (name.replacingOccurrences(of: "+", with: " "),
                        value.replacingOccurrences(of: "+", with: " "))
            }
            return nil
        }
    }
    
    public func flatFormData() -> [String:String] {
        let urlencodedForm = self.parseUrlencodedForm()
        var formData: [String:String] = [:]
        urlencodedForm.forEach{
            formData[$0.0] = $0.1
        }
        return formData
    }

    public func decodeFormData<T: Decodable>() throws -> T {
        try URLFormDecoder().decode(T.self, from: Data(body))
    }

    public func clientSupportsKeepAlive() -> Bool {
        if let value = self.headers["connection"] {
            return "keep-alive" == value.trimmingCharacters(in: .whitespaces).lowercased()
        }
        return false
    }

    public func queryParam(_ name: String) -> String? {
        return self.queryParams.first{ $0.0 == name }?.1
    }
    
    public func decodeQueryParams<T: Decodable>() throws -> T {
        let queryParams = self.queryParams.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        guard let data = queryParams.data(using: .utf8) else { throw HttpRequestError.invalidString }
        return try URLFormDecoder().decode(T.self, from: data)
    }

    public func decodePathParams<T: Decodable>() throws -> T {
        let queryParams = self.pathParams.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        guard let data = queryParams.data(using: .utf8) else { throw HttpRequestError.invalidString }
        return try URLFormDecoder().decode(T.self, from: data)
    }
    
    public func decodeHeaders<T: Decodable>() throws -> T {
        let headers = self.headers.map { "\($0.0.camelCased)=\($0.1)" }.joined(separator: "&")
        guard let data = headers.data(using: .utf8) else { throw HttpRequestError.invalidString }
        return try URLFormDecoder().decode(T.self, from: data)
    }
    
    public func decodeBody<T: Decodable>() throws -> T {
        try JSONDecoder().decode(T.self, from: Data(self.body))
    }

    public struct MultiPart {

        public let headers: [String: String]
        public let body: [UInt8]

        public var name: String? {
            return valueFor("content-disposition", parameter: "name")?.unquote()
        }

        public var fileName: String? {
            return valueFor("content-disposition", parameter: "filename")?.unquote()
        }

        private func valueFor(_ headerName: String, parameter: String) -> String? {
            return headers.reduce([String]()) { (combined, header: (key: String, value: String)) -> [String] in
                guard header.key == headerName else {
                    return combined
                }
                let headerValueParams = header.value.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                return headerValueParams.reduce(combined, { (results, token) -> [String] in
                    let parameterTokens = token.components(separatedBy: "=")
                    if parameterTokens.first == parameter, let value = parameterTokens.last {
                        return results + [value]
                    }
                    return results
                })
                }.first
        }
    }

    public func parseMultiPartFormData() -> [MultiPart] {
        guard let contentTypeHeader = headers["content-type"] else {
            return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let contentType = contentTypeHeaderTokens.first, contentType == "multipart/form-data" else {
            return []
        }
        var boundary: String?
        contentTypeHeaderTokens.forEach({
            let tokens = $0.components(separatedBy: "=")
            if let key = tokens.first, key == "boundary" && tokens.count == 2 {
                boundary = tokens.last
            }
        })
        if let boundary = boundary, boundary.utf8.count > 0 {
            return parseMultiPartFormData(body, boundary: "--\(boundary)")
        }
        return []
    }

    private func parseMultiPartFormData(_ data: [UInt8], boundary: String) -> [MultiPart] {
        var generator = data.makeIterator()
        var result = [MultiPart]()
        while let part = nextMultiPart(&generator, boundary: boundary, isFirst: result.isEmpty) {
            result.append(part)
        }
        return result
    }

    private func nextMultiPart(_ generator: inout IndexingIterator<[UInt8]>, boundary: String, isFirst: Bool) -> MultiPart? {
        if isFirst {
            guard nextUTF8MultiPartLine(&generator) == boundary else {
                return nil
            }
        } else {
            let /* ignore */ _ = nextUTF8MultiPartLine(&generator)
        }
        var headers = [String: String]()
        while let line = nextUTF8MultiPartLine(&generator), !line.isEmpty {
            let tokens = line.components(separatedBy: ":")
            if let name = tokens.first, let value = tokens.last, tokens.count == 2 {
                headers[name.lowercased()] = value.trimmingCharacters(in: .whitespaces)
            }
        }
        guard let body = nextMultiPartBody(&generator, boundary: boundary) else {
            return nil
        }
        return MultiPart(headers: headers, body: body)
    }

    private func nextUTF8MultiPartLine(_ generator: inout IndexingIterator<[UInt8]>) -> String? {
        var temp = [UInt8]()
        while let value = generator.next() {
            if value > HttpRequest.CR {
                temp.append(value)
            }
            if value == HttpRequest.NL {
                break
            }
        }
        return String(bytes: temp, encoding: String.Encoding.utf8)
    }

    // swiftlint:disable identifier_name
    static let CR = UInt8(13)
    static let NL = UInt8(10)

    private func nextMultiPartBody(_ generator: inout IndexingIterator<[UInt8]>, boundary: String) -> [UInt8]? {
        var body = [UInt8]()
        let boundaryArray = [UInt8](boundary.utf8)
        var matchOffset = 0
        while let x = generator.next() {
            matchOffset = ( x == boundaryArray[matchOffset] ? matchOffset + 1 : 0 )
            body.append(x)
            if matchOffset == boundaryArray.count {
                #if swift(>=4.2)
                body.removeSubrange(body.count-matchOffset ..< body.count)
                #else
                body.removeSubrange(CountableRange<Int>(body.count-matchOffset ..< body.count))
                #endif
                if body.last == HttpRequest.NL {
                    body.removeLast()
                    if body.last == HttpRequest.CR {
                        body.removeLast()
                    }
                }
                return body
            }
        }
        return nil
    }
}
