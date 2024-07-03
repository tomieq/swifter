//
//  URLSession+extension.swift
//
//
//  Created by Tomasz on 03/07/2024.
//

import Foundation


extension URLSession {
    func runTask(
        hostURL: URL = defaultLocalhost,
        completionHandler handler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        return self.dataTask(with: hostURL, completionHandler: handler)
    }

    /*
     usage:
     let semaphore = DispatchSemaphore(value: 0)
     URLSession.default.runRequest(semaphore, hostURL: defaultLocalhost.appendingPathComponent("book/34/esmeralda")) { body in
     }
     _ = semaphore.wait(timeout: .now() + .seconds(1))
     */
    func runRequest(_ semaphore: DispatchSemaphore, hostURL: URL = defaultLocalhost, body: ((String?) -> Void)? = nil ) {
        runTask(hostURL: hostURL) { data, response, error in
            guard error == nil else {
                print("runRequest error: \(error.debugDescription)")
                return
            }
            if let _ = response as? HTTPURLResponse {
                semaphore.signal()
            }
            if let data = data {
                body?(String(data: data, encoding: .utf8))
            }
        }.resume()
    }
    
    static var `default`: URLSession {
        URLSession(configuration: .default)
    }
}
