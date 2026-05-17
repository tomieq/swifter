import Foundation
import XCTest
@testable import Swifter

final class ParserSecurityTests: XCTestCase {
    private final class FakeSocket: SecureSocket {
        let id = UUID()
        let raw = Socket(socketFileDescriptor: -1)
        private var buffer: [UInt8]

        init(_ content: String) {
            self.buffer = Array(content.utf8)
        }

        func read() throws -> UInt8 {
            guard !self.buffer.isEmpty else { throw SocketError.recvFailed("eof") }
            return self.buffer.removeFirst()
        }

        func read(length: Int) throws -> [UInt8] {
            var output = [UInt8]()
            for _ in 0..<length {
                output.append(try self.read())
            }
            return output
        }

        func readLine() throws -> String {
            var bytes = [UInt8]()
            while true {
                let byte = try self.read()
                if byte == 10 { break }
                if byte > 13 { bytes.append(byte) }
            }
            return String(bytes: bytes, encoding: .utf8) ?? ""
        }

        func writeUTF8(_ string: String) throws {}
        func writeUInt8(_ data: [UInt8]) throws {}
        func writeUInt8(_ data: ArraySlice<UInt8>) throws {}
        func writeData(_ data: Data) throws {}
        func writeData(_ data: NSData) throws {}
        func writeFile(_ file: String.File) throws {}
        func close() {}
        var peerIP: String? { nil }
    }

    func testParsesChunkedTransferEncoding() throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n4;ext=value\r\nWiki\r\n5\r\npedia\r\n0\r\nExpires: never\r\n\r\n")
        let parser = HttpParser(bodyLimit: .unlimited)
        let request = try parser.readHttpRequest(sock)
        XCTAssertEqual(String(data: Data(request.body.raw), encoding: .utf8), "Wikipedia")
    }

    func testRejectsUnsupportedTransferEncoding() throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: gzip, chunked\r\n\r\n")
        let parser = HttpParser(bodyLimit: .unlimited)

        XCTAssertThrowsError(try parser.readHttpRequest(sock)) { error in
            XCTAssertEqual(error as? HttpParserError, .unsupportedTransferEncoding)
        }
    }

    func testRejectsInvalidChunkSize() throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nnope\r\n")
        let parser = HttpParser(bodyLimit: .unlimited)

        XCTAssertThrowsError(try parser.readHttpRequest(sock)) { error in
            XCTAssertEqual(error as? HttpParserError, .invalidChunkSize("nope"))
        }
    }

    func testRejectsInvalidChunkTerminator() throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nWikiXX0\r\n\r\n")
        let parser = HttpParser(bodyLimit: .unlimited)

        XCTAssertThrowsError(try parser.readHttpRequest(sock)) { error in
            XCTAssertEqual(error as? HttpParserError, .invalidChunkSize("4"))
        }
    }

    func testChunkedBodyLimitIsCheckedBeforeReadingChunk() throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n5\r\n")
        let parser = HttpParser(bodyLimit: .limit(DataSize(4)))
        let request = try parser.readHttpRequest(sock)

        guard case .exceededLimit(let bodySize) = request.body.status else {
            return XCTFail("Expected chunked body to exceed limit")
        }
        XCTAssertEqual(bodySize.count, 5)
        XCTAssertTrue(request.body.raw.isEmpty)
    }

    func testRejectsTooManyChunkTrailers() throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n0\r\nTrailer-One: 1\r\nTrailer-Two: 2\r\n\r\n")
        let parser = HttpParser(bodyLimit: .unlimited, maxHeadersCount: 1)

        XCTAssertThrowsError(try parser.readHttpRequest(sock)) { error in
            XCTAssertEqual(error as? HttpParserError, .headersTooLarge)
        }
    }

    func testRejectsTooManyHeaders() throws {
        let max = 5
        var request = "GET / HTTP/1.1\r\n"
        for i in 0..<(max + 1) {
            request.append("X-Test-\(i): value\r\n")
        }
        request.append("\r\n")
        let sock = FakeSocket(request)
        let parser = HttpParser(bodyLimit: .unlimited, maxHeadersCount: max)
        XCTAssertThrowsError(try parser.readHttpRequest(sock)) { error in
            XCTAssertTrue(error is HttpParserError)
            if let e = error as? HttpParserError {
                XCTAssertEqual(e, HttpParserError.headersTooLarge)
            }
        }
    }
}
