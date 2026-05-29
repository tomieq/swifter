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

// swiftlint:disable cyclomatic_complexity
public enum HttpResponse {
    case switchProtocols(HttpResponseHeaders, (SecureSocket) async -> Void)
    case processing(HttpResponseBody?)
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
    case uriTooLong(HttpResponseBody? = nil)
    case requestHeaderFieldsTooLarge(HttpResponseBody? = nil)
    case conflict(HttpResponseBody? = nil)
    case contentTooLarge(HttpResponseBody? = nil)
    case iAmTeapot(HttpResponseBody? = nil)
    case locked(HttpResponseBody? = nil)
    case tooEarly(HttpResponseBody? = nil)
    case noContent
    case tooManyRequests(HttpResponseBody? = nil)
    case internalServerError(HttpResponseBody? = nil)
    case notImplemented(HttpResponseBody? = nil)
    case badGateway(HttpResponseBody? = nil)
    case serviceUnavailable(HttpResponseBody? = nil)
    case gatewayTimeout(HttpResponseBody? = nil)
    case raw(Int, String, ((HttpResponseBodyWriter) async throws -> Void)?)
    case rawAsync(Int, String, ((HttpResponseBodyWriter) async throws -> Void)?)

    public var statusCode: Int {
        switch self {
        case .switchProtocols: return 101
        case .processing(_): return 102
        case .ok: return 200
        case .created: return 201
        case .accepted: return 202
        case .noContent: return 204
        case .movedPermanently: return 301
        case .found: return 302
        case .notModified: return 304
        case .movedTemporarily: return 307
        case .badRequest: return 400
        case .unauthorized: return 401
        case .forbidden: return 403
        case .notFound: return 404
        case .methodNotAllowed: return 405
        case .notAcceptable: return 406
        case .uriTooLong: return 414
        case .requestHeaderFieldsTooLarge: return 431
        case .conflict: return 409
        case .contentTooLarge: return 413
        case .iAmTeapot: return 418
        case .locked: return 423
        case .tooEarly: return 425
        case .tooManyRequests: return 429
        case .internalServerError: return 500
        case .notImplemented: return 501
        case .badGateway: return 502
        case .serviceUnavailable: return 503
        case .gatewayTimeout: return 504
        case .raw(let code, _, _), .rawAsync(let code, _, _): return code
        }
    }

    public var reasonPhrase: String {
        switch self {
        case .raw(_, let phrase, _), .rawAsync(_, let phrase, _): return phrase
        default: return HttpCode.description(for: self.statusCode) ?? "fatal error"
        }
    }

    public var responseHeaders: HttpResponseHeaders {
        let headers = HttpResponseHeaders()
        switch self {
        case .switchProtocols(let switchHeaders, _):
            switchHeaders.raw.forEach { header in
                headers.addHeader(header.name, header.value)
            }
        case .ok(let body):
            body.addHeader(to: headers)
        case .processing(let body), .badRequest(let body), .created(let body), .accepted(let body),
             .unauthorized(let body), .forbidden(let body), .notFound(let body),
             .methodNotAllowed(let body), .notAcceptable(let body), .conflict(let body),
             .contentTooLarge(let body), .iAmTeapot(let body), .locked(let body),
             .tooEarly(let body), .tooManyRequests(let body), .internalServerError(let body),
             .notImplemented(let body), .badGateway(let body), .serviceUnavailable(let body),
             .gatewayTimeout(let body), .uriTooLong(let body), .requestHeaderFieldsTooLarge(let body):
            body?.addHeader(to: headers)
        case .movedPermanently(let location), .movedTemporarily(let location), .found(let location):
            headers.addHeader(.location, location)
        case .notModified, .noContent, .raw, .rawAsync:
            break
        }
        return headers
    }

    func packet() -> HttpResponsePacket {
        switch self {
        case .ok(let body):
            return HttpResponsePacket(rawBody: body.raw, connection: .keepAlive)

        case .processing(let body),

             .created(let body), .accepted(let body), .unauthorized(let body),
             .notFound(let body), .methodNotAllowed(let body), .conflict(let body),
             .locked(let body), .tooEarly(let body), .internalServerError(let body),
             .notImplemented(let body), .badGateway(let body):
            return HttpResponsePacket(rawBody: body?.raw, connection: body == nil ? .closeConection : .keepAlive)

        case .badRequest(let body), .forbidden(let body), .notAcceptable(let body),
             .tooManyRequests(let body), .contentTooLarge(let body), .iAmTeapot(let body),
             .serviceUnavailable(let body), .gatewayTimeout(let body), .uriTooLong(let body), .requestHeaderFieldsTooLarge(let body):
            return HttpResponsePacket(rawBody: body?.raw, connection: .closeConection)

        case .raw(_, _, let writer):
            return HttpResponsePacket(rawBody: HttpResponseBodyRaw(.unknown, writer), connection: .keepAlive)

        case .rawAsync(_, _, let writer):
            return HttpResponsePacket(rawBody: HttpResponseBodyRaw(.unknown, writer), connection: .keepAlive)

        case .movedPermanently, .movedTemporarily, .noContent:
            return HttpResponsePacket(rawBody: nil, connection: .closeConection)

        case .switchProtocols, .notModified, .found:
            return HttpResponsePacket(rawBody: nil, connection: .keepAlive)
        }
    }

    func socketSession() -> ((SecureSocket) async -> Void)? {
        switch self {
        case .switchProtocols(_, let handler): return handler
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
