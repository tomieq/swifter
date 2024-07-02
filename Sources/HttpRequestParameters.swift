//
//  HttpRequestParameters.swift
//
//
//  Created by Tomasz on 02/07/2024.
//

import Foundation

public enum HttpRequestParamsError: Error {
    case invalidString
}

public class HttpRequestParams {
    var storage: [(String, String)] = []

    public var all: [(String, String)] {
        self.storage
    }
    
    init(_ params: [String : String]?) {
        guard let params = params else { return }
        self.storage = params.map{ ($0.key, $0.value) }
    }

    init(_ params: [(String, String)]?) {
        guard let params = params else { return }
        self.storage = params
    }

    public func get(_ name: String) -> String? {
        self[name]
    }

    public subscript(_ name: String) -> String? {
        get {
            self.storage.first { $0.0 == name }?.1
        }
    }

    public func decode<T: Decodable>() throws -> T {
        let queryParams = self.storage.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        guard let data = queryParams.data(using: .utf8) else { throw HttpRequestParamsError.invalidString }
        return try URLFormDecoder().decode(T.self, from: data)
    }
}
