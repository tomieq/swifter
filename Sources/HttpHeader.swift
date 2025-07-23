//
//  HttpHeader.swift
//  Swifter
//
//  Created by Tomasz Kucharski on 22/07/2025.
//

public enum HttpHeader: String {
    // incoming
    case connection = "Connection"
    case origin = "Origin"
    case accept = "Accept"
    case acceptEncoding = "Accept-Encoding"
    case acceptLanguage = "Accept-Language"
    case authorization = "Authorization"
    case host = "Host"
    case userAgent = "User-Agent"
    case xForwardedFor = "X-Forwarded-For"
    case xForwardedHost = "X-Forwarded-Host"
    // outgoing
    case contentType = "Content-Type"
    case contentLength = "Content-Length"
    case contentEncoding = "Content-Encoding"
    case transferEncoding = "Transfer-Encoding"
    case cacheControl = "Cache-Control"
    case setCookie = "Set-Cookie"
    case location = "Location"
    case accessControlAllowOrigin = "Access-Control-Allow-Origin"
    case accessControlAllowMethods = "Access-Control-Allow-Methods"
    case accessControlAllowHeaders = "Access-Control-Allow-Headers"
}

extension HttpHeader: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
