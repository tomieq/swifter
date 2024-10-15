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
        let expectation = expectation(description: "")
        DefaultSession().runRequest(url: defaultLocalhost.appendingPathComponent("api/v1")) { _, body in
            XCTAssertEqual(body, "InvalidVersion")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func testReturningResponseFromMiddleware() throws {
        server.get["api/v1"] = { _, _ in
            return .ok(.text("OK"))
        }
        server.middleware.append({ _, _ in
            throw HttpInstantResponse(response: .badRequest(.text("InstantMiddleware")))
        })
        try server.start()
        let expectation = expectation(description: "")
        DefaultSession().runRequest(url: defaultLocalhost.appendingPathComponent("api/v1")) { code, body in
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
        server.get["api/v1"] = { _, _ in
            throw CustomError.uups
        }
        server.globalErrorHandler = { error, request, headers in
            print("dupa")
            return .badRequest(.text("repacked"))
        }
        try server.start()
        let expectation = expectation(description: "")
        DefaultSession().runRequest(url: defaultLocalhost.appendingPathComponent("api/v1")) { code, body in
            expectation.fulfill()
            XCTAssertEqual(code, 400)
            XCTAssertEqual(body, "repacked")
            print("got it")
        }
        wait(for: [expectation], timeout: 10)
    }
}
