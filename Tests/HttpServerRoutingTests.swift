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
        server = HttpServer()
    }
    
    override func tearDown() {
        if server.operating {
            server.stop()
        }
        server = nil
        super.tearDown()
    }
    
    func testGroupedRouting() throws {
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
        try server.start()
        let expectation1 = expectation(description: "")
        URLSession.default.runRequest(url: defaultLocalhost.appendingPathComponent("users/5")) { _, body in
            XCTAssertEqual(body, "5")
            expectation1.fulfill()
        }
        let expectation2 = expectation(description: "")
        URLSession.default.runRequest(url: defaultLocalhost.appendingPathComponent("cars/bmw")) { _, body in
            XCTAssertEqual(body, "mainBMW")
            expectation2.fulfill()
        }
        let expectation3 = expectation(description: "")
        URLSession.default.runRequest(url: defaultLocalhost.appendingPathComponent("cars/bmw/z1"), method: "POST") { _, body in
            XCTAssertEqual(body, "cabrio")
            expectation3.fulfill()
        }
        wait(for: [expectation1, expectation2, expectation3], timeout: 2)
    }
    
    func testGroupedRoutingByWebPath() throws {
        enum LocalPath: String, WebPath {
            case series1
        }
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
        try server.start()
        let expectation1 = expectation(description: "")
        URLSession.default.runRequest(url: defaultLocalhost.appendingPathComponent("cars/bmw")) { _, body in
            XCTAssertEqual(body, "mainBMW")
            expectation1.fulfill()
        }
        let expectation2 = expectation(description: "")
        URLSession.default.runRequest(url: defaultLocalhost.appendingPathComponent("cars/bmw/series1"), method: "POST") { _, body in
            XCTAssertEqual(body, "post")
            expectation2.fulfill()
        }
        let expectation3 = expectation(description: "")
        URLSession.default.runRequest(url: defaultLocalhost.appendingPathComponent("cars/bmw/series1"), method: "GET") { _, body in
            XCTAssertEqual(body, "get")
            expectation3.fulfill()
        }
        wait(for: [expectation1, expectation2, expectation3], timeout: 3)
    }
}
