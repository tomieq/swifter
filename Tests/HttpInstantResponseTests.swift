//
//  HttpInstantResponseTests.swift
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

@Suite struct HttpInstantResponseTests {
    @Test func returningResponseFromHandler() async throws {
        let server = HttpServer()
        defer { stop(server) }
        server.get["api/:version"] = { request, _ in
            if request.pathParams.get("version") == "v1" {
                throw HttpInstantResponse(response: .ok(.text("InvalidVersion")))
            }
            return .ok(.text("OK"))
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)
        let response = try await DefaultSession().request(url: binding.host.appendingPathComponent("api/v1"))
        #expect(response.body == "InvalidVersion")
    }

    @Test func returningResponseFromAsyncHandler() async throws {
        let server = HttpServer()
        defer { stop(server) }
        server.get["api/v1"] = { _, _ in
            return .ok(.text("AsyncOK"))
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)
        let response = try await DefaultSession().request(url: binding.host.appendingPathComponent("api/v1"))
        #expect(response.body == "AsyncOK")
    }

    @Test func returningResponseFromMiddleware() async throws {
        let server = HttpServer()
        defer { stop(server) }
        server.get["api/v1"] = { _, _ in
            return .ok(.text("OK"))
        }
        server.middleware.append({ _, _ in
            throw HttpInstantResponse(response: .badRequest(.text("InstantMiddleware")))
        })
        let binding = ServerBinding.make()
        try server.start(binding.port)
        let response = try await DefaultSession().request(url: binding.host.appendingPathComponent("api/v1"))
        #expect(response.statusCode == 400)
        #expect(response.body == "InstantMiddleware")
    }

    @Test func returningResponseFromAsyncMiddleware() async throws {
        let server = HttpServer()
        defer { stop(server) }
        server.get["api/v1"] = { _, _ in
            return .ok(.text("OK"))
        }
        server.middleware.append { _, _ in
            await Task.yield()
            return .accepted(.text("AsyncMiddleware"))
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)
        let response = try await DefaultSession().request(url: binding.host.appendingPathComponent("api/v1"))
        #expect(response.statusCode == 202)
        #expect(response.body == "AsyncMiddleware")
    }

    @Test func globalErrorHandler() async throws {
        enum CustomError: Error {
            case uups
        }
        let server = HttpServer()
        defer { stop(server) }
        server.get["api/v1"] = { _, _ in
            throw CustomError.uups
        }
        server.globalErrorHandler = { _, _, _ in
            return .badRequest(.text("repacked"))
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)
        let response = try await DefaultSession().request(url: binding.host.appendingPathComponent("api/v1"))
        #expect(response.statusCode == 400)
        #expect(response.body == "repacked")
    }
}
