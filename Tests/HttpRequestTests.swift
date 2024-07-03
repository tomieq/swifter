//
//  HttpRequestTests.swift
//
//
//  Created by Tomasz on 25/05/2024.
//

import Foundation
import XCTest
@testable import Swifter

class HttpRequestTests: XCTestCase {
    
    func testformData() throws {
        struct FormData: Codable {
            let user: String
            let password: Int
        }
        let request = HttpRequest()
        request.headers = HttpRequestParams(["content-type":"application/x-www-form-urlencoded"])
        request.body = HttpRequestBody([UInt8]("user=John&password=1234".data(using: .utf8)!))
        let formData: FormData? = try request.formData.decode()
        XCTAssertEqual(formData?.user, "John")
        XCTAssertEqual(formData?.password, 1234)
    }

    func testQueryParams() throws {
        struct Search: Codable {
            let limit: Int
            let start: Int
            let query: String
        }
        let request = HttpRequest()
        request.queryParams = HttpRequestParams(["limit": "10", "query": "Warsaw", "start": "900"])
        let search: Search? = try request.queryParams.decode()
        XCTAssertEqual(search?.limit, 10)
        XCTAssertEqual(search?.query, "Warsaw")
        XCTAssertEqual(search?.start, 900)
    }

    func testDecodePathParams() throws {
        struct Book: Codable {
            let id: Int
            let title: String
        }
        let server = HttpServer()
        var expectedBook: Book?
        server.get["book/:id/:title"] = { request, _ in
            guard let book: Book = try? request.pathParams.decode() else {
                return .badRequest(.text("Invalid url"))
            }
            expectedBook = book
            return .ok(.text("Title: \(book.title)"))
        }
        defer {
            if server.operating {
                server.stop()
            }
        }
        try server.start()
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.default.runRequest(semaphore, hostURL: defaultLocalhost.appendingPathComponent("book/34/esmeralda"))
        _ = semaphore.wait(timeout: .now() + .seconds(1))
        XCTAssertEqual(expectedBook?.id, 34)
        XCTAssertEqual(expectedBook?.title, "esmeralda")
    }
}
