//
//  IOSafetyTests.swift
//  Swifter
//
//  Created by Brian Gerstle on 8/20/16.
//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif
import Testing
@testable import Swifter

@Suite struct IOSafetyTests {
    #if os(Linux)
    @Test func stopWithActiveConnectionsIsSkippedOnLinux() {}
    #else
    @Test func stopWithActiveConnections() async throws {
        let binding = ServerBinding.make()
        let urlSession = URLSession(configuration: .default)
        for cpt in 0...8 {
            let server = HttpServer.pingServer()
            do {
                try server.start(binding.port)
                #expect(try await urlSession.ping(hostURL: binding.host) == true)
                (0...100).forEach { _ in
                    DispatchQueue.global(qos: DispatchQoS.default.qosClass).sync {
                        urlSession.pingTask(hostURL: binding.host) { _, _, _ in }.resume()
                    }
                }
                server.stop()

                sleep(1)

            } catch {
                Issue.record("\(cpt): \(error)")
            }
        }
    }
    #endif
}
