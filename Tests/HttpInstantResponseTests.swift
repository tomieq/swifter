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
        server = HttpServer()
    }
    
    override func tearDown() {
        if server.operating {
            server.stop()
        }
        server = nil
        super.tearDown()
    }
    
    func testReturningResponseFromHandler() throws {
        server.get["api/:version"] = { request, _ in
            if request.pathParams.get("version") == "v1" {
                throw HttpInstantResponse(response: .ok(.text("InvalidVersion")))
            }
            return .ok(.text("OK"))
        }
        try server.start()
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.default.runRequest(semaphore, hostURL: defaultLocalhost.appendingPathComponent("api/v1")) { body in
            XCTAssertEqual(body, "InvalidVersion")
        }
        _ = semaphore.wait(timeout: .now() + .seconds(1))
    }
    
    func testReturningResponseFromMiddleware() throws {
        server.get["api/v1"] = { _, _ in
            return .ok(.text("OK"))
        }
        server.middleware.append({ _, _ in
            throw HttpInstantResponse(response: .ok(.text("InstantMiddleware")))
        })
        try server.start()
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.default.runRequest(semaphore, hostURL: defaultLocalhost.appendingPathComponent("api/v1")) { body in
            XCTAssertEqual(body, "InstantMiddleware")
        }
        _ = semaphore.wait(timeout: .now() + .seconds(1))
    }
}
