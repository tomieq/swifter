//
//  URLSession+extension.swift
//
//
//  Created by Tomasz on 03/07/2024.
//

import Foundation


extension URLSession {
    private func runTask(
        hostURL: URL = defaultLocalhost,
        completionHandler handler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        return self.dataTask(with: hostURL, completionHandler: handler)
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
    func runRequest(url: URL, body: ((Int, String?) -> Void)? = nil ) {
        runTask(hostURL: url) { data, response, error in
            guard error == nil else {
                print("runRequest error: \(error.debugDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                body?(httpResponse.statusCode, data?.asString)
            }
        }.resume()
    }
    
    static var `default`: URLSession {
        URLSession(configuration: .default)
    }
}

extension Data {
    var asString: String? {
        String(data: self, encoding: .utf8)
    }
}
