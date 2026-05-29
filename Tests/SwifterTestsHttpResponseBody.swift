import Foundation
import Testing
@testable import Swifter

@Suite struct SwifterTestsHttpResponseBody {
    @Test func dictionaryAsJSONPayload() async throws {
        try await self.verify(input: ["key": "value"], output: "{\"key\":\"value\"}")
        try await self.verify(input: ["key": ["value1", "value2", "value3"]], output: "{\"key\":[\"value1\",\"value2\",\"value3\"]}")
    }

    @Test func arrayAsJSONPayload() async throws {
        try await self.verify(input: ["key", "value"], output: "[\"key\",\"value\"]")
        try await self.verify(input: ["value1", "value2", "value3"], output: "[\"value1\",\"value2\",\"value3\"]")
    }

    @Test func nsDictionaryAsJSONPayload() async throws {
        try await self.verify(input: ["key": "value"], output: "{\"key\":\"value\"}")
        try await self.verify(input: ["key": ["value1", "value2", "value3"]], output: "{\"key\":[\"value1\",\"value2\",\"value3\"]}")
    }

    @Test func nsArrayAsJSONPayload() async throws {
        try await self.verify(input: ["key", "value"], output: "[\"key\",\"value\"]")
        try await self.verify(input: ["value1", "value2", "value3"], output: "[\"value1\",\"value2\",\"value3\"]")
    }

    private func verify(input: Encodable, output expectedOutput: String) async throws {
        let response: HttpResponseBody = .json(input)
        let writer = try #require(response.raw.write)

        let mockWriter = MockWriter()
        try await writer(mockWriter)
        let output = String(decoding: mockWriter.data, as: UTF8.self)
        #expect(output == expectedOutput)
    }
}

private final class MockWriter: HttpResponseBodyWriter {
    var data = Data()

    func write(_ file: String.File) async throws { }
    func write(_ data: [UInt8]) async throws { }
    func write(_ data: ArraySlice<UInt8>) async throws { }
    func write(_ data: NSData) async throws { }
    func write(_ data: Data) async throws { self.data = data }
}
