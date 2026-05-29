//
//  AsyncHandlerConcurrencyTests.swift
//  Swifter
//
//  Verifies the sync-to-async handler bridge in HttpServerIO is correct under
//  concurrent load and edge cases: real suspension points, path parameter
//  isolation between concurrent requests, middleware short-circuiting via
//  return value (not just throw), and the default 500 fallback when a handler
//  throws an arbitrary error with no global error handler installed.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import Testing
@testable import Swifter

@Suite struct AsyncHandlerConcurrencyTests {
    @Test func handlerCanSuspendOnAsyncWork() async throws {
        let server = HttpServer()
        defer { stop(server) }
        server.get["delay/:ms"] = { request, _ in
            let ms = UInt64(request.pathParams.get("ms") ?? "10") ?? 10
            try await Task.sleep(nanoseconds: ms * 1_000_000)
            return .ok(.text("slept-\(ms)"))
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)

        let response = try await DefaultSession()
            .request(url: binding.host.appendingPathComponent("delay/25"))
        #expect(response.statusCode == 200)
        #expect(response.body == "slept-25")
    }

    @Test func concurrentRequestsKeepPathParamsIsolated() async throws {
        let server = HttpServer()
        defer { stop(server) }
        server.get["echo/:value"] = { request, _ in
            // Introduce a small async suspension so requests really do interleave
            // through the cooperative executor.
            try await Task.sleep(nanoseconds: 5_000_000)
            let value = request.pathParams.get("value") ?? ""
            return .ok(.text(value))
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)

        let sample = (0..<20).map { "v\($0)" }
        let bodies = try await withThrowingTaskGroup(of: (String, String?).self) { group in
            for value in sample {
                group.addTask {
                    let result = try await DefaultSession()
                        .request(url: binding.host.appendingPathComponent("echo/\(value)"))
                    return (value, result.body)
                }
            }
            var collected: [(String, String?)] = []
            for try await pair in group {
                collected.append(pair)
            }
            return collected
        }

        #expect(bodies.count == sample.count)
        for (expected, body) in bodies {
            #expect(body == expected, "path param leaked across concurrent request for \(expected)")
        }
    }

    @Test func middlewareReturningResponseShortCircuitsHandler() async throws {
        let server = HttpServer()
        defer { stop(server) }
        let handlerInvocations = LockedValues<Int>()
        server.get["api/v1"] = { _, _ in
            handlerInvocations.append(1)
            return .ok(.text("handler"))
        }
        server.middleware.append { _, _ in
            // Return (not throw) a response - the handler must not run.
            return .badRequest(.text("blocked"))
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)

        let response = try await DefaultSession()
            .request(url: binding.host.appendingPathComponent("api/v1"))
        #expect(response.statusCode == 400)
        #expect(response.body == "blocked")
        #expect(handlerInvocations.values.isEmpty)
    }

    @Test func middlewareReturningNilFallsThroughToHandler() async throws {
        let server = HttpServer()
        defer { stop(server) }
        let middlewareInvocations = LockedValues<Int>()
        server.get["api/v1"] = { _, _ in
            return .ok(.text("handler"))
        }
        server.middleware.append { _, _ in
            middlewareInvocations.append(1)
            return nil
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)

        let response = try await DefaultSession()
            .request(url: binding.host.appendingPathComponent("api/v1"))
        #expect(response.statusCode == 200)
        #expect(response.body == "handler")
        #expect(middlewareInvocations.values == [1])
    }

    @Test func handlerThrowingArbitraryErrorReturns500() async throws {
        enum Boom: Error { case oops }
        let server = HttpServer()
        defer { stop(server) }
        server.get["fail"] = { _, _ in
            throw Boom.oops
        }
        // No globalErrorHandler installed - the default fallback must kick in.
        let binding = ServerBinding.make()
        try server.start(binding.port)

        let response = try await DefaultSession()
            .request(url: binding.host.appendingPathComponent("fail"))
        #expect(response.statusCode == 500)
    }

    @Test func middlewareThrowingArbitraryErrorIsHandled() async throws {
        enum Boom: Error { case oops }
        let server = HttpServer()
        defer { stop(server) }
        server.get["api/v1"] = { _, _ in
            return .ok(.text("handler"))
        }
        server.middleware.append { _, _ in
            throw Boom.oops
        }
        server.globalErrorHandler = { _, _, _ in
            return .badRequest(.text("caught-in-middleware"))
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)

        let response = try await DefaultSession()
            .request(url: binding.host.appendingPathComponent("api/v1"))
        #expect(response.statusCode == 400)
        #expect(response.body == "caught-in-middleware")
    }

    @Test func middlewareCanContributeHeadersViaInstantResponse() async throws {
        let server = HttpServer()
        defer { stop(server) }
        server.get["api/v1"] = { _, _ in
            return .ok(.text("never"))
        }
        server.middleware.append { _, _ in
            let extra = HttpResponseHeaders()
            extra.addHeader("X-Test", "from-middleware")
            throw HttpInstantResponse(response: .ok(.text("ok")), headers: extra)
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)

        let (data, response) = try await fetch(url: binding.host.appendingPathComponent("api/v1"))
        let http = response as? HTTPURLResponse
        #expect(http?.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
        let headerValue = (http?.value(forHTTPHeaderField: "X-Test")) ?? (http?.value(forHTTPHeaderField: "x-test"))
        #expect(headerValue == "from-middleware")
    }
}

private func fetch(url: URL, timeout: UInt64 = 5, retries: Int = 3) async throws -> (Data, URLResponse) {
    var lastError: Error?
    for attempt in 0...retries {
        do {
            return try await fetchOnce(url: url, timeout: timeout)
        } catch {
            lastError = error
            guard attempt < retries, error.isTransientURLSessionConnectionError else { throw error }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    throw lastError ?? TestTimeoutError.timedOut
}

private func fetchOnce(url: URL, timeout: UInt64) async throws -> (Data, URLResponse) {
    try await withTimeout(seconds: timeout) {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: url)
            request.setValue("close", forHTTPHeaderField: "Connection")
            DefaultSession().instance
                .dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: TestTimeoutError.timedOut)
                    }
                }
                .resume()
        }
    }
}
