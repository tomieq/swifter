//
//  ServerThreadingTests.swift
//  Swifter
//
//  Created by Victor Sigler on 4/22/19.
//  Copyright © 2019 Damian Kołakowski. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import Testing
@testable import Swifter

@Suite struct ServerThreadingTests {
    @Test func shouldHandleTheRequestInDifferentTimeIntervals() async throws {
        let path = "/a/:b/c"
        let server = HttpServer()
        defer { stop(server) }
        server.get[path] = { request, _ in .ok(.html("You asked for " + request.path)) }

        let binding = ServerBinding.make()
        try server.start(binding.port)

        async let first = self.delayedStatus(seconds: 1, hostURL: binding.host, path: path)
        async let second = self.delayedStatus(seconds: 2, hostURL: binding.host, path: path)
        async let third = self.delayedStatus(seconds: 3, hostURL: binding.host, path: path)
        let statusCodes = try await [first, second, third]
        #expect(statusCodes == [200, 200, 200])
    }

    @Test func shouldHandleTheSameRequestConcurrently() async throws {
        let path = "/a/:b/c"
        let server = HttpServer()
        defer { stop(server) }
        server.get[path] = { request, _ in .ok(.html("You asked for " + request.path)) }

        let binding = ServerBinding.make()
        try server.start(binding.port)

        let statusCodes = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    try await URLSession.shared.httpStatus(hostURL: binding.host, path: path, timeout: 15)
                }
            }
            var values: [Int] = []
            for try await value in group {
                values.append(value)
            }
            return values
        }
        #expect(statusCodes.sorted() == [200, 200, 200])
    }

    private func delayedStatus(seconds: UInt64, hostURL: URL, path: String) async throws -> Int {
        try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
        return try await URLSession.shared.httpStatus(hostURL: hostURL, path: path)
    }
}

extension URLSession {
    func executeAsyncTask(
        hostURL: URL,
        path: String,
        completionHandler handler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        var request = URLRequest(url: hostURL.appendingPathComponent(path))
        request.setValue("close", forHTTPHeaderField: "Connection")
        return self.dataTask(with: request, completionHandler: handler)
    }
}
