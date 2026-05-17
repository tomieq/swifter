//
//  ServerThreadingTests.swift
//  Swifter
//
//  Created by Victor Sigler on 4/22/19.
//  Copyright © 2019 Damian Kołakowski. All rights reserved.
//

import XCTest
import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import Swifter

class ServerThreadingTests: XCTestCase {
    var server: HttpServer!

    override func setUp() {
        super.setUp()
        self.server = HttpServer()
    }

    override func tearDown() {
        if self.server.operating {
            self.server.stop()
        }
        self.server = nil
        super.tearDown()
    }

    func testShouldHandleTheRequestInDifferentTimeIntervals() {
        let path = "/a/:b/c"
        let queue = DispatchQueue(label: "com.swifter.threading")

        self.server.get[path] = { request, _ in .ok(.html("You asked for " + request.path)) }

        do {
            let binding = ServerBinding.make()
            try self.server.start(binding.port)

            let requestGroup = DispatchGroup()
            let statusCodes = LockedValues<Int>()

            (1...3).forEach { index in
                requestGroup.enter()
                queue.asyncAfter(deadline: .now() + .seconds(index)) {
                    let task = URLSession.shared.executeAsyncTask(hostURL: binding.host, path: path) { _, response, _ in
                        let statusCode = (response as? HTTPURLResponse)?.statusCode
                        statusCodes.append(statusCode ?? -1)
                        requestGroup.leave()
                    }

                    task.resume()
                }
            }

            XCTAssertEqual(requestGroup.wait(timeout: .now() + 10), .success)
            XCTAssertEqual(statusCodes.values, [200, 200, 200], "\(binding.host)")

        } catch {
            XCTFail("\(error)")
        }
    }

    func testShouldHandleTheSameRequestConcurrently() {
        let path = "/a/:b/c"
        self.server.get[path] = { request, _ in .ok(.html("You asked for " + request.path)) }

        do {
            let binding = ServerBinding.make()
            try self.server.start(binding.port)
            let downloadGroup = DispatchGroup()
            let statusCodes = LockedValues<Int>()

            (0..<3).forEach { _ in
                downloadGroup.enter()
                DispatchQueue.global().async {
                    let task = URLSession.shared.executeAsyncTask(hostURL: binding.host, path: path) { _, response, _ in
                        let statusCode = (response as? HTTPURLResponse)?.statusCode
                        statusCodes.append(statusCode ?? -1)
                        downloadGroup.leave()
                    }

                    task.resume()
                }
            }

            XCTAssertEqual(downloadGroup.wait(timeout: .now() + 15), .success)
            XCTAssertEqual(statusCodes.values.sorted(), [200, 200, 200])

        } catch {
            XCTFail("\(error)")
        }
    }
}

private final class LockedValues<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []

    var values: [Value] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage
    }

    func append(_ value: Value) {
        self.lock.lock()
        self.storage.append(value)
        self.lock.unlock()
    }
}

extension URLSession {
    func executeAsyncTask(
        hostURL: URL,
        path: String,
        completionHandler handler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        return self.dataTask(with: hostURL.appendingPathComponent(path), completionHandler: handler)
    }
}
