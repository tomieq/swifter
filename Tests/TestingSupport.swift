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
    func request(url: URL, method: String = "GET", timeout: UInt64 = 5, retries: Int = 3) async throws -> HTTPResult {
        var lastError: Error?
        for attempt in 0...retries {
            do {
                return try await self.runRequestOnce(url: url, method: method, timeout: timeout)
            } catch {
                lastError = error
                guard attempt < retries, error.isTransientURLSessionConnectionError else { throw error }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        throw lastError ?? TestTimeoutError.timedOut
    }

    private func runRequestOnce(url: URL, method: String, timeout: UInt64) async throws -> HTTPResult {
        try await withTimeout(seconds: timeout) {
            try await withCheckedThrowingContinuation { continuation in
                self.runRequest(url: url, method: method) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let httpResponse = response as? HTTPURLResponse {
                        continuation.resume(returning: HTTPResult(statusCode: httpResponse.statusCode, body: data?.asString))
                    } else {
                        continuation.resume(throwing: TestTimeoutError.timedOut)
                    }
                }
            }
        }
    }
}

extension Error {
    var isTransientURLSessionConnectionError: Bool {
        let error = self as NSError
        return error.domain == NSURLErrorDomain && (error.code == -1005 || error.code == -1011)
    }
}

extension URLSession {
    func httpStatus(hostURL: URL, path: String, timeout: UInt64 = 5, retries: Int = 3) async throws -> Int {
        var lastError: Error?
        for attempt in 0...retries {
            do {
                return try await self.httpStatusOnce(hostURL: hostURL, path: path, timeout: timeout)
            } catch {
                lastError = error
                guard attempt < retries, error.isTransientURLSessionConnectionError else { throw error }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        throw lastError ?? TestTimeoutError.timedOut
    }

    private func httpStatusOnce(hostURL: URL, path: String, timeout: UInt64) async throws -> Int {
        try await withTimeout(seconds: timeout) {
            try await withCheckedThrowingContinuation { continuation in
                self.executeAsyncTask(hostURL: hostURL, path: path) { _, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                        continuation.resume(returning: statusCode)
                    } else {
                        continuation.resume(throwing: TestTimeoutError.timedOut)
                    }
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
