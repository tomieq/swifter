//
//  WebPath.swift
//
//
//  Created by Tomasz on 27/06/2024.
//

import Foundation

public protocol WebPath {
    var path: String { get }
}

extension WebPath where Self: RawRepresentable, Self.RawValue == String {
    public var path: String {
        self.rawValue
    }
}

extension HttpServer.MethodRoute {
    public subscript(webPath: WebPath) -> HttpRequestHandler? {
        set {
            router.register(nil, path: webPath.path, handler: newValue)
        }
        get { return nil }
    }
}

extension HttpServer.GroupedMethodRoute {
    public subscript(webPath: WebPath) -> HttpRequestHandler? {
        set {
            router.register(nil, path: webPath.path, handler: newValue)
        }
        get { return nil }
    }
}
