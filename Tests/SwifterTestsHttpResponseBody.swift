import Foundation
import Testing
@testable import Swifter

@Suite struct SwifterTestsHttpResponseBody {
    @Test func dictionaryAsJSONPayload() throws {
        try self.verify(input: ["key": "value"], output: "{\"key\":\"value\"}")
        try self.verify(input: ["key": ["value1", "value2", "value3"]], output: "{\"key\":[\"value1\",\"value2\",\"value3\"]}")
    }

    @Test func arrayAsJSONPayload() throws {
        try self.verify(input: ["key", "value"], output: "[\"key\",\"value\"]")
        try self.verify(input: ["value1", "value2", "value3"], output: "[\"value1\",\"value2\",\"value3\"]")
    }

    @Test func nsDictionaryAsJSONPayload() throws {
        try self.verify(input: ["key": "value"], output: "{\"key\":\"value\"}")
        try self.verify(input: ["key": ["value1", "value2", "value3"]], output: "{\"key\":[\"value1\",\"value2\",\"value3\"]}")
    }

    @Test func nsArrayAsJSONPayload() throws {
        try self.verify(input: ["key", "value"], output: "[\"key\",\"value\"]")
        try self.verify(input: ["value1", "value2", "value3"], output: "[\"value1\",\"value2\",\"value3\"]")
    }

    private func verify(input: Encodable, output expectedOutput: String) throws {
        let response: HttpResponseBody = .json(input)
        let writer = try #require(response.raw.write)

        let mockWriter = MockWriter()
        try writer(mockWriter)
        let output = String(decoding: mockWriter.data, as: UTF8.self)
        #expect(output == expectedOutput)
    }
}

private final class MockWriter: HttpResponseBodyWriter {
    var data = Data()

    func write(_ file: String.File) throws { }
    func write(_ data: [UInt8]) throws { }
    func write(_ data: ArraySlice<UInt8>) throws { }
    func write(_ data: NSData) throws { }
    func write(_ data: Data) throws { self.data = data }
}
