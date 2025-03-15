//
//  Middleware.swift
//  Swifter
//
//  Created by Tomasz on 14/03/2025.
//

public final class Middleware {
    var general = [HttpMiddlewareHandler]()
    let router = MiddlewareRouter()
    
    public func append(_ middleware: @escaping HttpMiddlewareHandler) {
        general.append(middleware)
    }
    
    public subscript(path: CustomStringConvertible) -> HttpMiddlewareHandler? {
        set {
            router.register(path: path.description, handler: newValue)
        }
        get { return nil }
    }

    public subscript(webPath: WebPath) -> HttpMiddlewareHandler? {
        set {
            router.register(path: webPath.path, handler: newValue)
        }
        get { return nil }
    }
}
