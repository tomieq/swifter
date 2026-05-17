//
//  SwifterTests.swift
//  SwifterTests
//
//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

import Testing
#if os(Linux)
import Glibc
#else
import Darwin
#endif
@testable import Swifter

@Suite struct SwifterTestsHttpParser {
    /// A specialized Socket which creates a linked socket pair with a pipe, and
    /// immediately writes in fixed data. This enables tests to static fixture
    /// data into the regular Socket flow.
    class TestSocket: DefaultSecureSocket {
        init(_ content: String) {
            /// Create an array to hold the read and write sockets that pipe creates
            var fds = [Int32](repeating: 0, count: 2)
            fds.withUnsafeMutableBufferPointer { ptr in
                let received = pipe(ptr.baseAddress!)
                guard received >= 0 else { fatalError("Pipe error!") }
            }

            // Extract the read and write handles into friendly variables
            let fdRead = fds[0]
            let fdWrite = fds[1]

            // Set non-blocking I/O on both sockets. This is required!
            _ = fcntl(fdWrite, F_SETFL, O_NONBLOCK)
            _ = fcntl(fdRead, F_SETFL, O_NONBLOCK)

            // Push the content bytes into the write socket.
            content.withCString { stringPointer in
                // Count will be either >=0 to indicate bytes written, or -1
                // if the bytes will be written later (non-blocking).
                let count = write(fdWrite, stringPointer, content.lengthOfBytes(using: .utf8) + 1)
                guard count != -1 || errno == EAGAIN else { fatalError("Write error!") }
            }

            // Close the write socket immediately. The OS will add an EOF byte
            // and the read socket will remain open.
            #if os(Linux)
            Glibc.close(fdWrite)
            #else
            Darwin.close(fdWrite) // the super instance will close fdRead in deinit!
            #endif

            super.init(Socket(socketFileDescriptor: fdRead))
        }
    }

    // swiftlint:disable function_body_length
    @Test func parser() {
        let parser = HttpParser(bodyLimit: .unlimited)

        do {
            _ = try parser.readHttpRequest(TestSocket(""))
            Issue.record("Parser should throw an error if socket is empty.")
        } catch { }

        do {
            _ = try parser.readHttpRequest(TestSocket("12345678"))
            Issue.record("Parser should throw an error if status line has single token.")
        } catch { }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET HTTP/1.0"))
            Issue.record("Parser should throw an error if status line has not enough tokens.")
        } catch { }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET / HTTP/1.0"))
            Issue.record("Parser should throw an error if there is no next line symbol.")
        } catch { }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET / HTTP/1.0"))
            Issue.record("Parser should throw an error if there is no next line symbol.")
        } catch { }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET / HTTP/1.0\r"))
            Issue.record("Parser should throw an error if there is no next line symbol.")
        } catch { }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET / HTTP/1.0\n"))
            Issue.record("Parser should throw an error if there is no 'Content-Length' header.")
        } catch { }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET / HTTP/1.0\r\nContent-Length: 0\r\n\r\n"))
        } catch {
            Issue.record("Parser should not throw any errors if there is a valid 'Content-Length' header.")
        }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET / HTTP/1.0\nContent-Length: 0\r\n\n"))
        } catch {
            Issue.record("Parser should not throw any errors if there is a valid 'Content-Length' header.")
        }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET / HTTP/1.0\r\nContent-Length: -1\r\n\r\n"))
        } catch {
            let error = error as? HttpParserError
            #expect(error != nil)
            #expect(error == HttpParserError.negativeContentLength)
        }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET / HTTP/1.0\nContent-Length: 5\n\n12345"))
        } catch {
            Issue.record("Parser should not throw any errors if there is a valid 'Content-Length' header.")
        }

        do {
            _ = try parser.readHttpRequest(TestSocket("GET / HTTP/1.0\nContent-Length: 10\r\n\n"))
            Issue.record("Parser should throw an error if request' body is too short.")
        } catch { }

        do { // test payload less than 1 read segmant
            let contentLength = Socket.kBufferLength - 128
            let bodyString = [String](repeating: "A", count: contentLength).joined(separator: "")

            let payload = "GET / HTTP/1.0\nContent-Length: \(contentLength)\n\n".appending(bodyString)
            let request = try parser.readHttpRequest(TestSocket(payload))

            #expect(bodyString.lengthOfBytes(using: .utf8) == contentLength)

            let unicodeBytes = bodyString.utf8.map { return $0 }
            #expect(request.body.raw == unicodeBytes)
        } catch { }

        do { // test payload equal to 1 read segmant
            let contentLength = Socket.kBufferLength
            let bodyString = [String](repeating: "B", count: contentLength).joined(separator: "")
            let payload = "GET / HTTP/1.0\nContent-Length: \(contentLength)\n\n".appending(bodyString)
            let request = try parser.readHttpRequest(TestSocket(payload))

            #expect(bodyString.lengthOfBytes(using: .utf8) == contentLength)

            let unicodeBytes = bodyString.utf8.map { return $0 }
            #expect(request.body.raw == unicodeBytes)
            #expect(request.body.string == bodyString)
        } catch { }

        do { // test very large multi-segment payload
            let contentLength = Socket.kBufferLength * 4
            let bodyString = [String](repeating: "C", count: contentLength).joined(separator: "")
            let payload = "GET / HTTP/1.0\nContent-Length: \(contentLength)\n\n".appending(bodyString)
            let request = try parser.readHttpRequest(TestSocket(payload))

            #expect(bodyString.lengthOfBytes(using: .utf8) == contentLength)

            let unicodeBytes = bodyString.utf8.map { return $0 }
            #expect(request.body.raw == unicodeBytes)
            #expect(request.body.string == bodyString)
        } catch { }

        var resp = try? parser.readHttpRequest(TestSocket("GET /open?link=https://www.youtube.com/watch?v=D2cUBG4PnOA HTTP/1.0\nContent-Length: 10\n\n1234567890"))

        #expect(resp?.queryParams.get("link") == "https://www.youtube.com/watch?v=D2cUBG4PnOA")
        #expect(resp?.method == .GET)
        #expect(resp?.path == "/open")
        #expect(resp?.headers["content-length"] == "10")

        resp = try? parser.readHttpRequest(TestSocket("POST / HTTP/1.0\nContent-Length: 10\n\n1234567890"))
        #expect(resp?.method == .POST)

        resp = try? parser.readHttpRequest(TestSocket("GET / HTTP/1.0\nHeader1: 1:1:34\nHeader2: 12345\nContent-Length: 0\n\n"))
        #expect(resp?.headers["header1"] == "1:1:34")

        resp = try? parser.readHttpRequest(TestSocket("GET / HTTP/1.0\nHeader1: 1\nHeader2: 2\nContent-Length: 0\n\n"))
        #expect(resp?.headers["header1"] == "1")
        #expect(resp?.headers["header2"] == "2")

        resp = try? parser.readHttpRequest(TestSocket("GET /some/path?subscript_query[]=1&subscript_query[]=2 HTTP/1.0\nContent-Length: 10\n\n1234567890"))
        var queryPairs = resp?.queryParams.list ?? []
        #expect(queryPairs.count == 2)
        #expect(queryPairs.first?.0 == "subscript_query[]")
        #expect(queryPairs.first?.1 == "1")
        #expect(queryPairs.last?.0 == "subscript_query[]")
        #expect(queryPairs.last?.1 == "2")
        #expect(resp?.method == .GET)
        #expect(resp?.path == "/some/path")
        #expect(resp?.headers["content-length"] == "10")

        resp = try? parser.readHttpRequest(TestSocket("GET /path[]/param?a[]=1&a[]=2&b=%20 HTTP/1.0\r\nContent-Length: 0\r\n\r\n"))
        queryPairs = resp?.queryParams.list ?? []

        #expect(resp?.path == "/path[]/param")
        if queryPairs.count == 3 {
            #expect(queryPairs[0].0 == "a[]")
            #expect(queryPairs[0].1 == "1")
            #expect(queryPairs[1].0 == "a[]")
            #expect(queryPairs[1].1 == "2")
            #expect(queryPairs[2].0 == "b")
            #expect(queryPairs[2].1 == " ")
        } else {
            Issue.record("queryPairs count should be 3")
        }
    }
}
