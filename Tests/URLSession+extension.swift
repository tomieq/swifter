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
     URLSession.default.runRequest(semaphore, hostURL: defaultLocalhost.appendingPathComponent("book/34/esmeralda"))
     _ = semaphore.wait(timeout: .now() + .seconds(1))
     */
    func runRequest(_ semaphore: DispatchSemaphore, hostURL: URL = defaultLocalhost) {
        runTask(hostURL: hostURL) { _, response, _ in
            if let _ = response as? HTTPURLResponse {
                semaphore.signal()
            }
        }.resume()
    }
    
    static var `default`: URLSession {
        URLSession(configuration: .default)
    }
}
