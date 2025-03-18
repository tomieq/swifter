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
        server = HttpServer.pingServer()
        urlSession = URLSession(configuration: .default)
    }

    override func tearDown() {
        if server.operating {
            server.stop()
        }

        urlSession = nil
        server = nil

        super.tearDown()
    }

    #if os(Linux)
    #else
    func testStopWithActiveConnections() {
        let binding = ServerBinding.make()
        (0...8).forEach { cpt in
            server = HttpServer.pingServer()
            do {
                try server.start(binding.port)
                XCTAssertFalse(urlSession.retryPing(hostURL: binding.host))
                (0...100).forEach { _ in
                    DispatchQueue.global(qos: DispatchQoS.default.qosClass).sync {
                        urlSession.pingTask(hostURL: binding.host) { _, _, _ in }.resume()
                    }
                }
                server.stop()
                
                    sleep(1)
                
            } catch let error {
                XCTFail("\(cpt): \(error)")
            }
        }
    }
    #endif
}
