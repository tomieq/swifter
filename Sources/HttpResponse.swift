//
//  HttpResponse.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public enum SerializationError: Error {
    case invalidObject
    case notSupported
}

public protocol HttpResponseBodyWriter {
    func write(_ file: String.File) throws
    func write(_ data: [UInt8]) throws
    func write(_ data: ArraySlice<UInt8>) throws
    func write(_ data: NSData) throws
    func write(_ data: Data) throws
}

public enum HttpResponseBody {

    case json(Encodable)
    case jsonString(CustomStringConvertible)
    case html(CustomStringConvertible)
    case text(CustomStringConvertible)
    case js(CustomStringConvertible)
    case css(CustomStringConvertible)
    case data(Data, contentType: String? = nil)
    case custom(Any, (Any) throws -> String)

    func content() -> (Int, ((HttpResponseBodyWriter) throws -> Void)?) {
        do {
            switch self {
            case .json(let object):
                let data = object.toJson() ?? Data()
                return (data.count, {
                    try $0.write(data)
                })
            case .text(let body), .jsonString(let body), .html(let body), .js(let body), .css(let body):
                let data = [UInt8](body.description.utf8)
                return (data.count, {
                    try $0.write(data)
                })
            case .data(let data, _):
                return (data.count, {
                    try $0.write(data)
                })
            case .custom(let object, let closure):
                let serialised = try closure(object)
                let data = [UInt8](serialised.utf8)
                return (data.count, {
                    try $0.write(data)
                })
            }
        } catch {
            let data = [UInt8]("Serialisation error: \(error)".utf8)
            return (data.count, {
                try $0.write(data)
            })
        }
    }
}

// swiftlint:disable cyclomatic_complexity
public enum HttpResponse {

    case switchProtocols(HttpResponseHeaders, (Socket) -> Void)
    case ok(HttpResponseBody)
    case created(HttpResponseBody? = nil)
    case accepted(HttpResponseBody? = nil)
    case movedPermanently(String)
    case movedTemporarily(String)
    case found(String)
    case notModified
    case badRequest(HttpResponseBody? = nil)
    case unauthorized(HttpResponseBody? = nil)
    case forbidden(HttpResponseBody? = nil)
    case notFound(HttpResponseBody? = nil)
    case methodNotAllowed(HttpResponseBody? = nil)
    case notAcceptable(HttpResponseBody? = nil)
    case iAmTeapot(HttpResponseBody? = nil)
    case tooEarly(HttpResponseBody? = nil)
    case noContent
    case tooManyRequests(HttpResponseBody? = nil)
    case internalServerError(HttpResponseBody? = nil)
    case notImplemented
    case badGateway, serviceUnavailable
    case raw(Int, String, ((HttpResponseBodyWriter) throws -> Void)? )

    public var statusCode: Int {
        switch self {
        case .switchProtocols         : return 101
        case .ok                      : return 200
        case .created                 : return 201
        case .accepted                : return 202
        case .noContent               : return 204
        case .movedPermanently        : return 301
        case .found                   : return 302
        case .notModified             : return 304
        case .movedTemporarily        : return 307
        case .badRequest              : return 400
        case .unauthorized            : return 401
        case .forbidden               : return 403
        case .notFound                : return 404
        case .methodNotAllowed        : return 405
        case .notAcceptable           : return 406
        case .iAmTeapot               : return 418
        case .tooEarly                : return 425
        case .tooManyRequests         : return 429
        case .internalServerError     : return 500
        case .notImplemented          : return 501
        case .badGateway              : return 502
        case .serviceUnavailable      : return 503
        case .raw(let code, _, _)  : return code
        }
    }

    public var reasonPhrase: String {
        switch self {
        case .switchProtocols          : return "Switching Protocols"
        case .ok                       : return "OK"
        case .created                  : return "Created"
        case .accepted                 : return "Accepted"
        case .noContent                : return "No Content"
        case .movedPermanently         : return "Moved Permanently"
        case .movedTemporarily         : return "Moved Temporarily"
        case .found                    : return "Found"
        case .notModified              : return "Not Modified"
        case .badRequest               : return "Bad Request"
        case .unauthorized             : return "Unauthorized"
        case .forbidden                : return "Forbidden"
        case .notFound                 : return "Not Found"
        case .methodNotAllowed         : return "Method Not Allowed"
        case .notAcceptable            : return "Not Acceptable"
        case .iAmTeapot                : return "I'm a teapot"
        case .tooEarly                 : return "Too Early"
        case .tooManyRequests          : return "Too Many Requests"
        case .internalServerError      : return "Internal Server Error"
        case .notImplemented           : return "Not Implemented"
        case .badGateway               : return "Bad Gateway"
        case .serviceUnavailable       : return "Service Unavailable"
        case .raw(_, let phrase, _)    : return phrase
        }
    }

    public func autoHeaders() -> HttpResponseHeaders {
        let headers = HttpResponseHeaders()
        switch self {
        case .switchProtocols(let switchHeaders, _):
            switchHeaders.raw.forEach { header in
                headers.addHeader(header.name, header.value)
            }
        case .ok(let body):
            self.addContentType(headers: headers, body: body)
        case .badRequest(let body), .created(let body), .accepted(let body),
                .unauthorized(let body), .forbidden(let body), .notFound(let body),
                .methodNotAllowed(let body), .notAcceptable(let body),
                .iAmTeapot(let body), .tooEarly(let body),
                .tooManyRequests(let body), .internalServerError(let body):
            guard let body = body else { break }
            self.addContentType(headers: headers, body: body)
        case .movedPermanently(let location), .movedTemporarily(let location), .found(let location):
            headers.addHeader("Location", location)
        default:
            break
        }
        return headers
    }
    
    func addContentType(headers: HttpResponseHeaders, body: HttpResponseBody) {
        switch body {
        case .json, .jsonString:
            headers.addHeader("Content-Type", "application/json; charset=utf-8")
        case .html:
            headers.addHeader("Content-Type", "text/html; charset=utf-8")
        case .text:
            headers.addHeader("Content-Type", "text/plain; charset=utf-8")
        case .js:
            headers.addHeader("Content-Type", "text/javascript; charset=utf-8")
        case .css:
            headers.addHeader("Content-Type", "text/css")
        case .data(_, let contentType):
            headers.addHeader("Content-Type", contentType ?? "")
        default:
            break
        }
    }

    func content() -> (length: Int, write: ((HttpResponseBodyWriter) throws -> Void)?) {
        switch self {
        case .ok(let body):
            return body.content()
        case .badRequest(let body), .unauthorized(let body), .forbidden(let body), .notFound(let body),
             .tooManyRequests(let body), .internalServerError(let body), .created(let body), .accepted(let body):
            return body?.content() ?? (-1, nil)
        case .raw(_, _, let writer):
            return (-1, writer)
        default:
            return (-1, nil)
        }
    }

    func socketSession() -> ((Socket) -> Void)? {
        switch self {
        case .switchProtocols(_, let handler) : return handler
        default: return nil
        }
    }
}

/**
    Makes it possible to compare handler responses with '==', but
	ignores any associated values. This should generally be what
	you want. E.g.:

    let resp = handler(updatedRequest)
        if resp == .NotFound {
        print("Client requested not found: \(request.url)")
    }
*/

func == (inLeft: HttpResponse, inRight: HttpResponse) -> Bool {
    return inLeft.statusCode == inRight.statusCode
}

fileprivate extension Encodable {
    func toJson() -> Data? {
        do {
            return try JSONEncoder().encode(self)
        } catch {
            return nil
        }
    }
}
