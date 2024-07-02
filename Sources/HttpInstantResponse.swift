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

enum HttpInstantResponseHandler {
    static func watch(_ request: HttpRequest, _ headers: HttpResponseHeaders, _ handler: HttpRequestHandler) -> HttpResponse {
        do {
            return try handler(request, headers)
        } catch {
            if let instantResponse = error as? HttpInstantResponse {
                headers.merge(instantResponse.headers)
                return instantResponse.response
            }
            return .internalServerError(.text("Unexpected error \(error)"))
        }
    }
}
