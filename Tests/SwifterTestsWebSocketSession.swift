//
//  SwifterTests.swift
//  SwifterTests
//
//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

import Testing
@testable import Swifter

@Suite struct SwifterTestsWebSocketSession {
    class TestSocket: DefaultSecureSocket {
        var content = [UInt8]()
        var offset = 0

        init(_ content: [UInt8]) {
            super.init(Socket(socketFileDescriptor: -1))
            self.content.append(contentsOf: content)
        }

        override func read() throws -> UInt8 {
            if self.offset < self.content.count {
                let value = self.content[self.offset]
                self.offset += 1
                return value
            }
            throw SocketError.recvFailed("")
        }

        override func writeUInt8(_ data: [UInt8]) throws { }
        override func writeUInt8(_ data: ArraySlice<UInt8>) throws { }
        override func close() { }
    }

    // swiftlint:disable function_body_length
    @Test func parser() {
        do {
            let session = WebSocketSession(TestSocket([0]))
            _ = try session.readFrame()
            Issue.record("Parser should throw an error if socket has not enough data for a frame.")
        } catch {
        }

        do {
            let session = WebSocketSession(TestSocket([0b0000_0001, 0b0000_0000, 0, 0, 0, 0]))
            _ = try session.readFrame()
            Issue.record("Parser should not accept unmasked frames.")
        } catch WebSocketSession.WsError.unMaskedFrame {
        } catch {
            Issue.record("Parse should throw UnMaskedFrame error for unmasked message.")
        }

        do {
            let session = WebSocketSession(TestSocket([0b1000_0001, 0b1000_0000, 0, 0, 0, 0]))
            let frame = try session.readFrame()
            #expect(frame.fin)
        } catch {
            Issue.record("Parser should not throw an error for a frame with fin flag set (\(error)")
        }

        do {
            let session = WebSocketSession(TestSocket([0b0000_0000, 0b1000_0000, 0, 0, 0, 0]))
            let frame = try session.readFrame()
            #expect(frame.opcode == WebSocketSession.OpCode.continue)
        } catch {
            Issue.record("Parser should accept Continue opcode without any errors.")
        }

        do {
            let session = WebSocketSession(TestSocket([0b0000_0001, 0b1000_0000, 0, 0, 0, 0]))
            let frame = try session.readFrame()
            #expect(frame.opcode == WebSocketSession.OpCode.text)
        } catch {
            Issue.record("Parser should accept Text opcode without any errors.")
        }

        do {
            let session = WebSocketSession(TestSocket([0b0000_0010, 0b1000_0000, 0, 0, 0, 0]))
            let frame = try session.readFrame()
            #expect(frame.opcode == WebSocketSession.OpCode.binary)
        } catch {
            Issue.record("Parser should accept Binary opcode without any errors.")
        }

        do {
            let session = WebSocketSession(TestSocket([0b1000_1000, 0b1000_0000, 0, 0, 0, 0]))
            let frame = try session.readFrame()
            #expect(frame.opcode == WebSocketSession.OpCode.close)
        } catch {
            Issue.record("Parser should accept Close opcode without any errors. \(error)")
        }

        do {
            let session = WebSocketSession(TestSocket([0b1000_1001, 0b1000_0000, 0, 0, 0, 0]))
            let frame = try session.readFrame()
            #expect(frame.opcode == WebSocketSession.OpCode.ping)
        } catch {
            Issue.record("Parser should accept Ping opcode without any errors. \(error)")
        }

        do {
            let session = WebSocketSession(TestSocket([0b1000_1010, 0b1000_0000, 0, 0, 0, 0]))
            let frame = try session.readFrame()
            #expect(frame.opcode == WebSocketSession.OpCode.pong)
        } catch {
            Issue.record("Parser should accept Pong opcode without any errors. \(error)")
        }

        for opcode in [3, 4, 5, 6, 7, 11, 12, 13, 14, 15] {
            do {
                let session = WebSocketSession(TestSocket([UInt8(opcode), 0b1000_0000, 0, 0, 0, 0]))
                _ = try session.readFrame()
                Issue.record("Parse should throw an error for unknown opcode: \(opcode)")
            } catch WebSocketSession.WsError.unknownOpCode(_) {
            } catch {
                Issue.record("Parse should throw UnknownOpCode error for unknown opcode (was \(error)).")
            }
        }
    }
}
