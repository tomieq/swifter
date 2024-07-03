//
//  HttpServer.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

open class HttpServer: HttpServerIO {

    let router = HttpRouter()

    public override init() {
        self.delete = MethodRoute(method: .DELETE, router: router)
        self.patch  = MethodRoute(method: .PATCH, router: router)
        self.head   = MethodRoute(method: .HEAD, router: router)
        self.post   = MethodRoute(method: .POST, router: router)
        self.get    = MethodRoute(method: .GET, router: router)
        self.put    = MethodRoute(method: .PUT, router: router)
    }

    public var delete, patch, head, post, get, put: MethodRoute

    public subscript(path: String) -> HttpRequestHandler? {
        set {
            router.register(nil, path: path, handler: newValue)
        }
        get { return nil }
    }

    public subscript(webPath: WebPath) -> HttpRequestHandler? {
        set {
            router.register(nil, path: webPath.path, handler: newValue)
        }
        get { return nil }
    }

    public var routes: [String] {
        return router.routes()
    }

    public var notFoundHandler: HttpRequestHandler?

    public var middleware = [HttpMiddlewareHandler]()

    override open func dispatch(_ request: HttpRequest, _ responseHeaders: HttpResponseHeaders) -> ([String: String], HttpRequestHandler) {
        for layer in middleware {
            if let response = HttpInstantResponseHandler.watch(request, responseHeaders, layer) {
                return ([:], { (_, _) in response })
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
        public subscript(path: String) -> HttpRequestHandler? {
            set {
                router.register(method, path: path, handler: newValue)
            }
            get { return nil }
        }
    }
}
