//
//  PingServer.swift
//  Swifter
//
//  Created by Brian Gerstle on 8/20/16.
//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import Swifter
import Dispatch

// Server
extension HttpServer {
    class func pingServer() -> HttpServer {
        let server = HttpServer()
        server.get["/ping"] = { request, _ in
            return HttpResponse.ok(.text("pong!"))
        }
        return server
    }
}

struct ServerBinding {
    let port: UInt16
    let host: URL

    static func make() -> ServerBinding {
        self.queue.sync {
            ServerBinding.nextPort += 1
            return ServerBinding(port: ServerBinding.nextPort, host: URL(string: "http://127.0.0.1:\(ServerBinding.nextPort)")!)
        }
    }

    private static var nextPort: UInt16 = 9080
    private static let queue = DispatchQueue(label: "serverbinding.init")
}

// Client
extension URLSession {
    func pingTask(
        hostURL: URL,
        completionHandler handler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        return self.dataTask(with: hostURL.appendingPathComponent("/ping"), completionHandler: handler)
    }

    func retryPing(
        hostURL: URL,
        timeout: Double = 2.0
    ) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        self.signalIfPongReceived(semaphore, hostURL: hostURL)

        let result = semaphore.wait(timeout: .now() + timeout)
        switch result {
        case .success:
            return false
        case .timedOut:
            return true
        }
    }

    func signalIfPongReceived(_ semaphore: DispatchSemaphore, hostURL: URL) {
        self.pingTask(hostURL: hostURL) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                semaphore.signal()
            } else {
                self.signalIfPongReceived(semaphore, hostURL: hostURL)
            }
        }.resume()
    }
}
