//
//  HttpMultiPartParser.swift
//  Swifter
//
//  Created by Tomasz on 29/04/2025.
//

enum HttpMultiPartParser {
    static func parseMultiPartFormData(_ request: HttpRequest) -> [HttpMultiPart] {
        guard let contentTypeHeader = request.headers["content-type"] else {
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
            return Self.parseMultiPartFormData(request.body.raw, boundary: "--\(boundary)")
        }
        return []
    }

    private static func parseMultiPartFormData(_ data: [UInt8], boundary: String) -> [HttpMultiPart] {
        var generator = data.makeIterator()
        var result = [HttpMultiPart]()
        while let part = nextMultiPart(&generator, boundary: boundary, isFirst: result.isEmpty) {
            result.append(part)
        }
        return result
    }

    private static func nextMultiPart(_ generator: inout IndexingIterator<[UInt8]>, boundary: String, isFirst: Bool) -> HttpMultiPart? {
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
        guard let body = Self.nextMultiPartBody(&generator, boundary: boundary) else {
            return nil
        }
        return HttpMultiPart(headers: headers, body: body)
    }

    private static func nextUTF8MultiPartLine(_ generator: inout IndexingIterator<[UInt8]>) -> String? {
        var temp = [UInt8]()
        while let value = generator.next() {
            if value > Self.CR {
                temp.append(value)
            }
            if value == Self.NL {
                break
            }
        }
        return String(bytes: temp, encoding: String.Encoding.utf8)
    }

    // swiftlint:disable identifier_name
    static let CR = UInt8(13)
    static let NL = UInt8(10)

    private static func nextMultiPartBody(_ generator: inout IndexingIterator<[UInt8]>, boundary: String) -> [UInt8]? {
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
                if body.last == Self.NL {
                    body.removeLast()
                    if body.last == Self.CR {
                        body.removeLast()
                    }
                }
                return body
            }
        }
        return nil
    }
}
