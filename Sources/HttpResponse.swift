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
    case html(String)
    case htmlBody(String)
    case text(String)
    case javaScript(String)
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
            case .text(let body):
                let data = [UInt8](body.utf8)
                return (data.count, {
                    try $0.write(data)
                })
            case .html(let html):
                let data = [UInt8](html.utf8)
                return (data.count, {
                    try $0.write(data)
                })
            case .htmlBody(let body):
                let serialised = "<html><meta charset=\"UTF-8\"><body>\(body)</body></html>"
                let data = [UInt8](serialised.utf8)
                return (data.count, {
                    try $0.write(data)
                })
            case .javaScript(let body):
                let data = [UInt8](body.utf8)
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
    case ok(HttpResponseBody), created, accepted
    case movedPermanently(String)
    case movedTemporarily(String)
    case badRequest(HttpResponseBody?), unauthorized, forbidden, notFound, notAcceptable
    case noContent
    case tooManyRequests
    case internalServerError
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
        case .movedTemporarily        : return 307
        case .badRequest              : return 400
        case .unauthorized            : return 401
        case .forbidden               : return 403
        case .notFound                : return 404
        case .notAcceptable           : return 406
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
        case .badRequest               : return "Bad Request"
        case .unauthorized             : return "Unauthorized"
        case .forbidden                : return "Forbidden"
        case .notFound                 : return "Not Found"
        case .notAcceptable            : return "Not Acceptable"
        case .tooManyRequests          : return "Too Many Requests"
        case .internalServerError      : return "Internal Server Error"
        case .notImplemented           : return "Not Implemented"
        case .badGateway               : return "Bad Gateway"
        case .serviceUnavailable       : return "Service Unavailable"
        case .raw(_, let phrase, _) : return phrase
        }
    }

    public func autoHeaders() -> HttpResponseHeaders{
        let headers = HttpResponseHeaders().addHeader("Server", "Swifter \(HttpServer.VERSION)")
        switch self {
        case .switchProtocols(let switchHeaders, _):
            switchHeaders.raw.forEach { header in
                headers.addHeader(header.name, header.value)
            }
        case .ok(let body):
            switch body {
            case .json: headers.addHeader("Content-Type", "application/json")
            case .html: headers.addHeader("Content-Type", "text/html")
            case .javaScript: headers.addHeader("Content-Type", "text/javascript")
            case .data(_, let contentType): headers.addHeader("Content-Type", contentType ?? "")
            default: break
            }
        case .movedPermanently(let location):
            headers.addHeader("Location", location)
        case .movedTemporarily(let location):
            headers.addHeader("Location", location)
        default: break
        }
        return headers
    }

    func content() -> (length: Int, write: ((HttpResponseBodyWriter) throws -> Void)?) {
        switch self {
        case .ok(let body)             : return body.content()
        case .badRequest(let body)     : return body?.content() ?? (-1, nil)
        case .raw(_, _, let writer) : return (-1, writer)
        default                        : return (-1, nil)
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
