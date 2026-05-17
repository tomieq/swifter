//
//  SwifterTestsHttpResponseBody.swift
//  Swifter
//

import XCTest
@testable import Swifter

class SwifterTestsHttpResponseBody: XCTestCase {
    func testDictionaryAsJSONPayload() {
        self.verify(input: ["key": "value"], output: "{\"key\":\"value\"}")
        self.verify(input: ["key": ["value1", "value2", "value3"]], output: "{\"key\":[\"value1\",\"value2\",\"value3\"]}")
    }

    func testArrayAsJSONPayload() {
        self.verify(input: ["key", "value"], output: "[\"key\",\"value\"]")
        self.verify(input: ["value1", "value2", "value3"], output: "[\"value1\",\"value2\",\"value3\"]")
    }

    func testNSDictionaryAsJSONPayload() {
        self.verify(input: ["key": "value"], output: "{\"key\":\"value\"}")
        self.verify(input: ["key": ["value1", "value2", "value3"]], output: "{\"key\":[\"value1\",\"value2\",\"value3\"]}")
    }

    func testNSArrayAsJSONPayload() {
        self.verify(input: ["key", "value"], output: "[\"key\",\"value\"]")
        self.verify(input: ["value1", "value2", "value3"], output: "[\"value1\",\"value2\",\"value3\"]")
    }

    private func verify(input: Encodable, output expectedOutput: String, line: UInt = #line) {
        let response: HttpResponseBody = .json(input)

        guard let writer = response.raw.write else {
            XCTFail(line: line)
            return
        }

        do {
            let mockWriter = MockWriter()
            try writer(mockWriter)
            let output = String(decoding: mockWriter.data, as: UTF8.self)
            XCTAssertEqual(output, expectedOutput, line: line)
        } catch {
            XCTFail(line: line)
        }
    }
}

private class MockWriter: HttpResponseBodyWriter {
    var data = Data()

    func write(_ file: String.File) throws { }
    func write(_ data: [UInt8]) throws { }
    func write(_ data: ArraySlice<UInt8>) throws { }
    func write(_ data: NSData) throws { }
    func write(_ data: Data) throws { self.data = data }
}
