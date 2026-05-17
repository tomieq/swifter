//
//  IOSafetyTests.swift
//  Swifter
//
//  Created by Brian Gerstle on 8/20/16.
//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

import XCTest
#if os(Linux)
import FoundationNetworking
#endif
@testable import Swifter

class IOSafetyTests: XCTestCase {
    var server: HttpServer!
    var urlSession: URLSession!

    override func setUp() {
        super.setUp()
        self.server = HttpServer.pingServer()
        self.urlSession = URLSession(configuration: .default)
    }

    override func tearDown() {
        if self.server.operating {
            self.server.stop()
        }

        self.urlSession = nil
        self.server = nil

        super.tearDown()
    }

    #if os(Linux)
    func testStopWithActiveConnectionsIsSkippedOnLinux() {}
    #else
    func testStopWithActiveConnections() {
        let binding = ServerBinding.make()
        (0...8).forEach { cpt in
            self.server = HttpServer.pingServer()
            do {
                try self.server.start(binding.port)
                XCTAssertFalse(self.urlSession.retryPing(hostURL: binding.host))
                (0...100).forEach { _ in
                    DispatchQueue.global(qos: DispatchQoS.default.qosClass).sync {
                        self.urlSession.pingTask(hostURL: binding.host) { _, _, _ in }.resume()
                    }
                }
                self.server.stop()

                sleep(1)

            } catch {
                XCTFail("\(cpt): \(error)")
            }
        }
    }
    #endif
}
