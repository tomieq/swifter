import Foundation
import XCTest
@testable import Swifter

final class ParserSecurityTests: XCTestCase {
    private class FakeSocket: SecureSocket {
        let id = UUID()
        let raw = Socket(socketFileDescriptor: -1)
        private var lines: [String]
        init(lines: [String]) {
            self.lines = lines
        }

        func readLine() throws -> String {
            guard !self.lines.isEmpty else { return "" }
            return self.lines.removeFirst()
        }

        func read() throws -> UInt8 { throw SocketError.recvFailed("no-op") }
        func read(length: Int) throws -> [UInt8] { return [] }
        func writeUTF8(_ string: String) throws {}
        func writeUInt8(_ data: [UInt8]) throws {}
        func writeUInt8(_ data: ArraySlice<UInt8>) throws {}
        func writeData(_ data: Data) throws {}
        func writeData(_ data: NSData) throws {}
        func writeFile(_ file: String.File) throws {}
        func close() {}
        var peerIP: String? { nil }
    }

    func testRejectsChunkedTransferEncoding() throws {
        let lines = ["GET / HTTP/1.1\r\n", "Transfer-Encoding: chunked\r\n", "\r\n"]
        let sock = FakeSocket(lines: lines)
        let parser = HttpParser(bodyLimit: .unlimited)
        XCTAssertThrowsError(try parser.readHttpRequest(sock)) { error in
            XCTAssertTrue(error is HttpParserError)
            if let e = error as? HttpParserError {
                XCTAssertEqual(e, HttpParserError.unsupportedTransferEncoding)
            }
        }
    }

    func testRejectsTooManyHeaders() throws {
        // Allow only 5 headers
        let max = 5
        var lines = [String]()
        lines.append("GET / HTTP/1.1\r\n")
        for i in 0..<(max + 1) {
            lines.append("X-Test-\(i): value\r\n")
        }
        lines.append("\r\n")
        let sock = FakeSocket(lines: lines)
        let parser = HttpParser(bodyLimit: .unlimited, maxHeadersCount: max)
        XCTAssertThrowsError(try parser.readHttpRequest(sock)) { error in
            XCTAssertTrue(error is HttpParserError)
            if let e = error as? HttpParserError {
                XCTAssertEqual(e, HttpParserError.headersTooLarge)
            }
        }
    }
}
