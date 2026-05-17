//
//  HttpServer.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

open class HttpServer: HttpServerIO, @unchecked Sendable {
    let router = HttpRouter()

    public override init() {
        self.delete = MethodRoute(method: .DELETE, router: self.router)
        self.patch = MethodRoute(method: .PATCH, router: self.router)
        self.head = MethodRoute(method: .HEAD, router: self.router)
        self.post = MethodRoute(method: .POST, router: self.router)
        self.get = MethodRoute(method: .GET, router: self.router)
        self.put = MethodRoute(method: .PUT, router: self.router)
        self.connect = MethodRoute(method: .CONNECT, router: self.router)
        self.options = MethodRoute(method: .OPTIONS, router: self.router)
        self.trace = MethodRoute(method: .TRACE, router: self.router)
    }

    public var delete, patch, head, post, get, put, connect, options, trace: MethodRoute

    public subscript(path: CustomStringConvertible) -> HttpRequestHandler? {
        set {
            self.router.register(nil, path: path.description, handler: newValue)
        }
        get { return nil }
    }

    public subscript(webPath: WebPath) -> HttpRequestHandler? {
        set {
            self.router.register(nil, path: webPath.path, handler: newValue)
        }
        get { return nil }
    }

    public var routes: [String] {
        return self.router.routes()
    }

    public var notFoundHandler: HttpRequestHandler?

    public var middleware = Middleware()

    override open func dispatch(_ request: HttpRequest, _ responseHeaders: HttpResponseHeaders) -> ([String: String], HttpRequestHandler) {
        for layer in self.middleware.general + self.middleware.router.layers(path: request.path) {
            if let response = self.instantRequestHandler.watch(request, responseHeaders, layer) {
                return ([:], { _, _ in response })
            }
        }
        if let result = router.route(request.method, path: request.path) {
            return result
        }
        if let notFoundHandler = self.notFoundHandler {
            return ([:], notFoundHandler)
        }
        return super.dispatch(request, responseHeaders)
    }

    public struct MethodRoute {
        public let method: HttpMethod
        public let router: HttpRouter
        public subscript(path: CustomStringConvertible) -> HttpRequestHandler? {
            set {
                self.router.register(self.method, path: path.description, handler: newValue)
            }
            get { return nil }
        }
    }
}
