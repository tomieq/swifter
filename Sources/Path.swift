//
//  Path.swift
//
//
//  Created by Tomasz on 27/06/2024.
//

import Foundation

public protocol Path {
    var path: String { get }
}

extension Path where Self: RawRepresentable, Self.RawValue == String {
    public var path: String {
        self.rawValue
    }
}

extension HttpServer.MethodRoute {
    public subscript(obj: Path) -> ((HttpRequest, HttpResponseHeaders) -> HttpResponse)? {
        set {
            router.register(nil, path: obj.path, handler: newValue)
        }
        get { return nil }
    }
}
