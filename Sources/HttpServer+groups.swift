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

        public var delete, patch, head, post, get, put, connect, options, trace: GroupedMethodRoute

        init(_ commonPath: String, router: HttpRouter) {
            self.commonPath = commonPath
            self.router = router

            self.delete = GroupedMethodRoute(commonPath: commonPath, method: .DELETE, router: router)
            self.patch = GroupedMethodRoute(commonPath: commonPath, method: .PATCH, router: router)
            self.head = GroupedMethodRoute(commonPath: commonPath, method: .HEAD, router: router)
            self.post = GroupedMethodRoute(commonPath: commonPath, method: .POST, router: router)
            self.get = GroupedMethodRoute(commonPath: commonPath, method: .GET, router: router)
            self.put = GroupedMethodRoute(commonPath: commonPath, method: .PUT, router: router)
            self.connect = GroupedMethodRoute(commonPath: commonPath, method: .CONNECT, router: router)
            self.options = GroupedMethodRoute(commonPath: commonPath, method: .OPTIONS, router: router)
            self.trace = GroupedMethodRoute(commonPath: commonPath, method: .TRACE, router: router)
        }

        public func grouped(_ name: String) -> GroupedRoute {
            GroupedRoute(self.commonPath + "/" + name.trimmedSlashes, router: self.router)
        }

        public func group(_ name: String, _ setup: @escaping (GroupedRoute) -> Void) {
            setup(self.grouped(name))
        }
    }

    public struct GroupedMethodRoute {
        let commonPath: String
        let method: HttpMethod
        let router: HttpRouter

        public subscript(path: CustomStringConvertible) -> HttpRequestHandler? {
            set {
                self.register(path: path.description, handler: newValue)
            }
            get { return nil }
        }

        public var handler: HttpRequestHandler? {
            set {
                self.register(path: "", handler: newValue)
            }
            get { return nil }
        }

        func register(path: String, handler: HttpRequestHandler?) {
            self.router.register(self.method, path: self.commonPath + "/" + path.trimmedSlashes, handler: handler)
        }
    }
}
