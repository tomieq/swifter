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
    
    func testformData() {
        struct FormData: Codable {
            let user: String
            let password: Int
        }
        let request = HttpRequest()
        request.body = [UInt8]("user=John&password=1234".data(using: .utf8)!)
        let formData: FormData? = request.decodeFormData()
        XCTAssertEqual(formData?.user, "John")
        XCTAssertEqual(formData?.password, 1234)
    }

    func testQueryParams() {
        struct Search: Codable {
            let limit: Int
            let start: Int
            let query: String
        }
        let request = HttpRequest()
        request.queryParams = [("limit", "10"), ("query", "Warsaw"), ("start", "900")]
        let search: Search? = request.decodeQueryParams()
        XCTAssertEqual(search?.limit, 10)
        XCTAssertEqual(search?.query, "Warsaw")
        XCTAssertEqual(search?.start, 900)
    }
}
