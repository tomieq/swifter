//
//  URLSession+extension.swift
//
//
//  Created by Tomasz on 03/07/2024.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class DefaultSession: @unchecked Sendable {
    private static let shared = URLSession(configuration: .default)

    let instance: URLSession

    init() {
        self.instance = Self.shared
    }

    private func runTask(
        hostURL: URL,
        method: String = "GET",
        completionHandler handler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        var request = URLRequest(url: hostURL)
        request.httpMethod = method
        request.setValue("close", forHTTPHeaderField: "Connection")
        return self.instance.dataTask(with: request, completionHandler: handler)
    }

    func runRequest(
        url: URL,
        method: String = "GET",
        completion: (@Sendable (Data?, URLResponse?, Error?) -> Void)? = nil
    ) {
        self.runTask(hostURL: url, method: method) { data, response, error in
            completion?(data, response, error)
        }.resume()
    }
}

extension Data {
    var asString: String? {
        String(data: self, encoding: .utf8)
    }
}
