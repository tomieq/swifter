//
//  HttpInstantResponse.swift
//
//
//  Created by Tomasz on 02/07/2024.
//

import Foundation

public struct HttpInstantResponse: Error {
    let response: HttpResponse
    let headers: HttpResponseHeaders
    
    public init(response: HttpResponse, headers: HttpResponseHeaders? = nil) {
        self.response = response
        self.headers = headers ?? HttpResponseHeaders()
    }
}

class HttpInstantResponseHandler {
    var errorHandler: HttpGlobalErrorHandler?
    func watch(_ request: HttpRequest, _ headers: HttpResponseHeaders, _ handler: HttpRequestHandler) -> HttpResponse {
        do {
            return try handler(request, headers)
        } catch {
            if let instantResponse = error as? HttpInstantResponse {
                headers.merge(instantResponse.headers)
                return instantResponse.response
            }
            return self.errorHandler?(error, headers) ?? .internalServerError(.text("Unexpected error \(error)"))
        }
    }

    func watch(_ request: HttpRequest, _ headers: HttpResponseHeaders, _ handler: HttpMiddlewareHandler) -> HttpResponse? {
        do {
            return try handler(request, headers)
        } catch {
            if let instantResponse = error as? HttpInstantResponse {
                headers.merge(instantResponse.headers)
                return instantResponse.response
            }
            return self.errorHandler?(error, headers) ?? .internalServerError(.text("Unexpected error \(error)"))
        }
    }
}
