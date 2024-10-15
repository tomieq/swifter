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

class DefaultSession {
    let instance: URLSession
    
    init() {
        self.instance = URLSession(configuration: .default)
    }
    
    private func runTask(
        hostURL: URL = defaultLocalhost,
        method: String = "GET",
        completionHandler handler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        var request = URLRequest(url: hostURL)
        request.httpMethod = method
        return instance.dataTask(with: request, completionHandler: handler)
    }

    /*
     usage:
     let expectation = expectation(description: "description")
     URLSession.default.runRequest(url: defaultLocalhost.appendingPathComponent("users/5")) { body in
         XCTAssertEqual(body, "5")
         expectation.fulfill()
     }
     wait(for: [expectation], timeout: 1)
     */
    func runRequest(url: URL, method: String = "GET", body: ((Int, String?) -> Void)? = nil) {
        runTask(hostURL: url, method: method) { data, response, error in
            guard error == nil else {
                print("runRequest error: \(error.debugDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                body?(httpResponse.statusCode, data?.asString)
            }
        }.resume()
    }

}

extension Data {
    var asString: String? {
        String(data: self, encoding: .utf8)
    }
}
