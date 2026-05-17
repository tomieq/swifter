//
//  HttpInstantResponseTests.swift
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

class HttpInstantResponseTests: XCTestCase {
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

    func testReturningResponseFromHandler() throws {
        self.server.get["api/:version"] = { request, _ in
            if request.pathParams.get("version") == "v1" {
                throw HttpInstantResponse(response: .ok(.text("InvalidVersion")))
            }
            return .ok(.text("OK"))
        }
        let binding = ServerBinding.make()
        try self.server.start(binding.port)
        let expectation = expectation(description: "")
        DefaultSession().runRequest(url: binding.host.appendingPathComponent("api/v1")) { _, body in
            XCTAssertEqual(body, "InvalidVersion")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testReturningResponseFromMiddleware() throws {
        self.server.get["api/v1"] = { _, _ in
            return .ok(.text("OK"))
        }
        self.server.middleware.append({ _, _ in
            throw HttpInstantResponse(response: .badRequest(.text("InstantMiddleware")))
        })
        let binding = ServerBinding.make()
        try self.server.start(binding.port)
        let expectation = expectation(description: "")
        DefaultSession().runRequest(url: binding.host.appendingPathComponent("api/v1")) { code, body in
            XCTAssertEqual(code, 400)
            XCTAssertEqual(body, "InstantMiddleware")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testGlobalErrorHandler() throws {
        enum CustomError: Error {
            case uups
        }
        self.server.get["api/v1"] = { _, _ in
            throw CustomError.uups
        }
        self.server.globalErrorHandler = { error, request, headers in
            return .badRequest(.text("repacked"))
        }
        let binding = ServerBinding.make()
        try self.server.start(binding.port)
        let expectation = expectation(description: "")
        DefaultSession().runRequest(url: binding.host.appendingPathComponent("api/v1")) { code, body in
            expectation.fulfill()
            XCTAssertEqual(code, 400)
            XCTAssertEqual(body, "repacked")
        }
        wait(for: [expectation], timeout: 10)
    }
}
