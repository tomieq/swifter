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

        func read() async throws -> UInt8 {
            guard !self.buffer.isEmpty else { throw SocketError.recvFailed("eof") }
            return self.buffer.removeFirst()
        }

        func read(length: Int) async throws -> [UInt8] {
            var output = [UInt8]()
            for _ in 0..<length {
                output.append(try await self.read())
            }
            return output
        }

        func readLine() async throws -> String {
            var bytes = [UInt8]()
            while true {
                let byte = try await self.read()
                if byte == 10 { break }
                if byte > 13 { bytes.append(byte) }
            }
            return String(bytes: bytes, encoding: .utf8) ?? ""
        }

        func writeUTF8(_ string: String) async throws {}
        func writeUInt8(_ data: [UInt8]) async throws {}
        func writeUInt8(_ data: ArraySlice<UInt8>) async throws {}
        func writeData(_ data: Data) async throws {}
        func writeData(_ data: NSData) async throws {}
        func writeFile(_ file: String.File) async throws {}
        func close() {}
        var peerIP: String? { nil }
    }

    func testParsesChunkedTransferEncoding() async throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n4;ext=value\r\nWiki\r\n5\r\npedia\r\n0\r\nExpires: never\r\n\r\n")
        let parser = HttpParser(bodyLimit: .unlimited)
        let request = try await parser.readHttpRequest(sock)
        XCTAssertEqual(String(data: Data(request.body.raw), encoding: .utf8), "Wikipedia")
    }

    func testRejectsUnsupportedTransferEncoding() async throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: gzip, chunked\r\n\r\n")
        let parser = HttpParser(bodyLimit: .unlimited)

        await assertThrowsAsync({ _ = try await parser.readHttpRequest(sock) }) { error in
            XCTAssertEqual(error as? HttpParserError, .unsupportedTransferEncoding)
        }
    }

    func testRejectsInvalidChunkSize() async throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nnope\r\n")
        let parser = HttpParser(bodyLimit: .unlimited)

        await assertThrowsAsync({ _ = try await parser.readHttpRequest(sock) }) { error in
            XCTAssertEqual(error as? HttpParserError, .invalidChunkSize("nope"))
        }
    }

    func testRejectsInvalidChunkTerminator() async throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nWikiXX0\r\n\r\n")
        let parser = HttpParser(bodyLimit: .unlimited)

        await assertThrowsAsync({ _ = try await parser.readHttpRequest(sock) }) { error in
            XCTAssertEqual(error as? HttpParserError, .invalidChunkSize("4"))
        }
    }

    func testChunkedBodyLimitIsCheckedBeforeReadingChunk() async throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n5\r\n")
        let parser = HttpParser(bodyLimit: .limit(DataSize(4)))
        let request = try await parser.readHttpRequest(sock)

        guard case .exceededLimit(let bodySize) = request.body.status else {
            return XCTFail("Expected chunked body to exceed limit")
        }
        XCTAssertEqual(bodySize.count, 5)
        XCTAssertTrue(request.body.raw.isEmpty)
    }

    func testRejectsTooManyChunkTrailers() async throws {
        let sock = FakeSocket("GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n0\r\nTrailer-One: 1\r\nTrailer-Two: 2\r\n\r\n")
        let parser = HttpParser(bodyLimit: .unlimited, maxHeadersCount: 1)

        await assertThrowsAsync({ _ = try await parser.readHttpRequest(sock) }) { error in
            XCTAssertEqual(error as? HttpParserError, .headersTooLarge)
        }
    }

    func testRejectsTooManyHeaders() async throws {
        let max = 5
        var request = "GET / HTTP/1.1\r\n"
        for i in 0..<(max + 1) {
            request.append("X-Test-\(i): value\r\n")
        }
        request.append("\r\n")
        let sock = FakeSocket(request)
        let parser = HttpParser(bodyLimit: .unlimited, maxHeadersCount: max)
        await assertThrowsAsync({ _ = try await parser.readHttpRequest(sock) }) { error in
            XCTAssertTrue(error is HttpParserError)
            if let e = error as? HttpParserError {
                XCTAssertEqual(e, HttpParserError.headersTooLarge)
            }
        }
    }

    private func assertThrowsAsync(_ operation: () async throws -> Void, verify: (Error) -> Void) async {
        do {
            try await operation()
            XCTFail("Expected operation to throw")
        } catch {
            verify(error)
        }
    }
}
