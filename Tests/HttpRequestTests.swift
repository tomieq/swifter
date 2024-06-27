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
}
