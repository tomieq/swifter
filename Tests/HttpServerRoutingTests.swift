//
//  HttpServerRoutingTests.swift
//
//
//  Created by Tomasz on 03/07/2024.
//

import Foundation
import XCTest
#if os(Linux)
import FoundationNetworking
#endif
@testable import Swifter

class HttpServerRoutingTests: XCTestCase {
    var server: HttpServer!

    override func setUp() {
        super.setUp()
        self.server = HttpServer()
    }

    override func tearDown() {
        if self.server.operating {
            self.server.stop()
        }
        self.server = nil
        super.tearDown()
    }

    func testGroupedRouting() throws {
        let users = self.server.grouped("users")
        users.get[":id"] = { request, _ in
            let userID = request.pathParams.get("id") ?? ""
            return .ok(.text(userID))
        }
        let cars = self.server.grouped("cars")
        cars.group("bmw") { bmw in
            bmw.get.handler = { _, _ in
                .ok(.text("mainBMW"))
            }
            bmw.post["z1"] = { _, _ in
                .ok(.text("cabrio"))
            }
        }
        let binding = ServerBinding.make()
        try self.server.start(binding.port)
        let requestGroup = DispatchGroup()
        let responses = RoutingLockedValues<String>()
        requestGroup.enter()
        DefaultSession().runRequest(url: binding.host.appendingPathComponent("users/5")) { _, body in
            responses.append(body ?? "")
            requestGroup.leave()
        }
        requestGroup.enter()
        DefaultSession().runRequest(url: binding.host.appendingPathComponent("cars/bmw")) { _, body in
            responses.append(body ?? "")
            requestGroup.leave()
        }
        requestGroup.enter()
        DefaultSession().runRequest(url: binding.host.appendingPathComponent("cars/bmw/z1"), method: "POST") { _, body in
            responses.append(body ?? "")
            requestGroup.leave()
        }
        XCTAssertEqual(requestGroup.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(responses.values.sorted(), ["5", "cabrio", "mainBMW"])
    }

    func testGroupedRoutingByWebPath() throws {
        enum LocalPath: String, WebPath {
            case series1
        }
        let cars = self.server.grouped("cars")
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
        try self.server.start(binding.port)
        let requestGroup = DispatchGroup()
        let responses = RoutingLockedValues<String>()
        requestGroup.enter()
        DefaultSession().runRequest(url: binding.host.appendingPathComponent("cars/bmw")) { _, body in
            responses.append(body ?? "")
            requestGroup.leave()
        }
        requestGroup.enter()
        DefaultSession().runRequest(url: binding.host.appendingPathComponent("cars/bmw/series1"), method: "POST") { _, body in
            responses.append(body ?? "")
            requestGroup.leave()
        }
        requestGroup.enter()
        DefaultSession().runRequest(url: binding.host.appendingPathComponent("cars/bmw/series1"), method: "GET") { _, body in
            responses.append(body ?? "")
            requestGroup.leave()
        }
        XCTAssertEqual(requestGroup.wait(timeout: .now() + 3), .success)
        XCTAssertEqual(responses.values.sorted(), ["get", "mainBMW", "post"])
    }
}

private final class RoutingLockedValues<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []

    var values: [Value] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage
    }

    func append(_ value: Value) {
        self.lock.lock()
        self.storage.append(value)
        self.lock.unlock()
    }
}
