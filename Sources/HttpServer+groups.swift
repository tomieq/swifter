//
//  HttpServer+groups.swift
//
//
//  Created by Tomasz on 02/07/2024.
//

import Foundation

extension HttpServer {
    
    public func grouped(_ name: String) -> GroupedRoute {
        GroupedRoute(name.trimmedSlashes, router: self.router)
    }
    
    public func group(_ name: String, _ setup: @escaping (GroupedRoute) -> Void) {
        setup(self.grouped(name))
    }

    public class GroupedRoute {
        let commonPath: String
        let router: HttpRouter
        
        public var DELETE, PATCH, HEAD, POST, GET, PUT: GroupedMethodRoute
        public var delete, patch, head, post, get, put: GroupedMethodRoute
        
        init(_ commonPath: String, router: HttpRouter) {
            self.commonPath = commonPath
            self.router = router
            self.DELETE = GroupedMethodRoute(commonPath: commonPath, method: .DELETE, router: router)
            self.PATCH  = GroupedMethodRoute(commonPath: commonPath, method: .PATCH, router: router)
            self.HEAD   = GroupedMethodRoute(commonPath: commonPath, method: .HEAD, router: router)
            self.POST   = GroupedMethodRoute(commonPath: commonPath, method: .POST, router: router)
            self.GET    = GroupedMethodRoute(commonPath: commonPath, method: .GET, router: router)
            self.PUT    = GroupedMethodRoute(commonPath: commonPath, method: .PUT, router: router)

            self.delete = GroupedMethodRoute(commonPath: commonPath, method: .DELETE, router: router)
            self.patch  = GroupedMethodRoute(commonPath: commonPath, method: .PATCH, router: router)
            self.head   = GroupedMethodRoute(commonPath: commonPath, method: .HEAD, router: router)
            self.post   = GroupedMethodRoute(commonPath: commonPath, method: .POST, router: router)
            self.get    = GroupedMethodRoute(commonPath: commonPath, method: .GET, router: router)
            self.put    = GroupedMethodRoute(commonPath: commonPath, method: .PUT, router: router)
        }
    }

    public struct GroupedMethodRoute {
        let commonPath: String
        let method: HttpMethod
        let router: HttpRouter
        public subscript(path: String) -> HttpRequestHandler? {
            set {
                router.register(method, path: commonPath + "/" + path.trimmedSlashes, handler: newValue)
            }
            get { return nil }
        }
    }
}
