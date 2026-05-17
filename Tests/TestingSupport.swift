import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Swifter

struct HTTPResult: Sendable {
    let statusCode: Int
    let body: String?
}

enum TestTimeoutError: Error {
    case timedOut
}

func withTimeout<Value: Sendable>(seconds: UInt64, operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            throw TestTimeoutError.timedOut
        }

        guard let result = try await group.next() else {
            throw TestTimeoutError.timedOut
        }
        group.cancelAll()
        return result
    }
}

final class LockedValues<Value>: @unchecked Sendable {
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

final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value?

    var value: Value? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage
    }

    func set(_ value: Value) {
        self.lock.lock()
        self.storage = value
        self.lock.unlock()
    }
}

extension DefaultSession {
    func request(url: URL, method: String = "GET", timeout: UInt64 = 5) async throws -> HTTPResult {
        try await withTimeout(seconds: timeout) {
            await withCheckedContinuation { continuation in
                self.runRequest(url: url, method: method) { statusCode, body in
                    continuation.resume(returning: HTTPResult(statusCode: statusCode, body: body))
                }
            }
        }
    }
}

extension URLSession {
    func httpStatus(hostURL: URL, path: String, timeout: UInt64 = 5) async throws -> Int {
        try await withTimeout(seconds: timeout) {
            await withCheckedContinuation { continuation in
                self.executeAsyncTask(hostURL: hostURL, path: path) { _, response, _ in
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    continuation.resume(returning: statusCode)
                }.resume()
            }
        }
    }

    func ping(hostURL: URL, timeout: UInt64 = 5) async throws -> Bool {
        try await withTimeout(seconds: timeout) {
            await withCheckedContinuation { continuation in
                self.pingTask(hostURL: hostURL) { _, response, _ in
                    let success = (response as? HTTPURLResponse)?.statusCode == 200
                    continuation.resume(returning: success)
                }.resume()
            }
        }
    }
}

func stop(_ server: HttpServer) {
    if server.operating {
        server.stop()
    }
}
