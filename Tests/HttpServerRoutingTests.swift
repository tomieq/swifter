//
//  HttpServerRoutingTests.swift
//
//
//  Created by Tomasz on 03/07/2024.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import Testing
@testable import Swifter

@Suite struct HttpServerRoutingTests {
    @Test func groupedRouting() async throws {
        let server = HttpServer()
        defer { stop(server) }
        let users = server.grouped("users")
        users.get[":id"] = { request, _ in
            let userID = request.pathParams.get("id") ?? ""
            return .ok(.text(userID))
        }
        let cars = server.grouped("cars")
        cars.group("bmw") { bmw in
            bmw.get.handler = { _, _ in
                .ok(.text("mainBMW"))
            }
            bmw.post["z1"] = { _, _ in
                .ok(.text("cabrio"))
            }
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)

        let responses = try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask { try await DefaultSession().request(url: binding.host.appendingPathComponent("users/5")).body }
            group.addTask { try await DefaultSession().request(url: binding.host.appendingPathComponent("cars/bmw")).body }
            group.addTask { try await DefaultSession().request(url: binding.host.appendingPathComponent("cars/bmw/z1"), method: "POST").body }
            var values: [String] = []
            for try await body in group {
                if let body {
                    values.append(body)
                }
            }
            return values.sorted()
        }
        #expect(responses == ["5", "cabrio", "mainBMW"])
    }

    @Test func groupedRoutingByWebPath() async throws {
        enum LocalPath: String, WebPath {
            case series1
        }
        let server = HttpServer()
        defer { stop(server) }
        let cars = server.grouped("cars")
        cars.group("bmw") { bmw in
            bmw.get.handler = { _, _ in
                .ok(.text("mainBMW"))
            }
            bmw.post[LocalPath.series1] = { _, _ in
                .ok(.text("post"))
            }
            bmw.get[LocalPath.series1] = { _, _ in
                .ok(.text("get"))
            }
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)

        let responses = try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask { try await DefaultSession().request(url: binding.host.appendingPathComponent("cars/bmw")).body }
            group.addTask { try await DefaultSession().request(url: binding.host.appendingPathComponent("cars/bmw/series1"), method: "POST").body }
            group.addTask { try await DefaultSession().request(url: binding.host.appendingPathComponent("cars/bmw/series1"), method: "GET").body }
            var values: [String] = []
            for try await body in group {
                if let body {
                    values.append(body)
                }
            }
            return values.sorted()
        }
        #expect(responses == ["get", "mainBMW", "post"])
    }
}
