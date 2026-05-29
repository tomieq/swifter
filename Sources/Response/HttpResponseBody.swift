//
//  HttpResponseBody.swift
//  Swifter
//
//  Created by Tomasz Kucharski on 23/07/2025.
//
import Foundation

public enum HttpResponseBody {
    case json(Encodable)
    case jsonString(CustomStringConvertible)
    case html(CustomStringConvertible)
    case text(CustomStringConvertible)
    case js(CustomStringConvertible)
    case css(CustomStringConvertible)
    case xml(CustomStringConvertible)
    case data(Data, contentType: String? = nil)

    var raw: HttpResponseBodyRaw {
        switch self {
        case .json(let object):
            let data = object.toJson() ?? Data()
            return HttpResponseBodyRaw(.fixedSize(data.count), {
                try await $0.write(data)
            })
        case .text(let body), .jsonString(let body), .html(let body),
             .js(let body), .css(let body), .xml(let body):
            let data = [UInt8](body.description.utf8)
            return HttpResponseBodyRaw(.fixedSize(data.count), {
                try await $0.write(data)
            })
        case .data(let data, _):
            return HttpResponseBodyRaw(.fixedSize(data.count), {
                try await $0.write(data)
            })
        }
    }

    func addHeader(to headers: HttpResponseHeaders) {
        switch self {
        case .json, .jsonString:
            headers.addHeader(.contentType, "application/json; charset=utf-8")
        case .html:
            headers.addHeader(.contentType, "text/html; charset=utf-8")
        case .text:
            headers.addHeader(.contentType, "text/plain; charset=utf-8")
        case .js:
            headers.addHeader(.contentType, "text/javascript; charset=utf-8")
        case .css:
            headers.addHeader(.contentType, "text/css")
        case .xml:
            headers.addHeader(.contentType, "text/xml; charset=utf-8")
        case .data(_, let contentType):
            if let contentType = contentType {
                headers.addHeader(.contentType, contentType)
            }
        }
    }
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
