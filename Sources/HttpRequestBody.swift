//
//  HttpRequestBody.swift
//
//
//  Created by Tomasz on 03/07/2024.
//

import Foundation

public enum HttpRequestBodyStatus {
    case ok
    case exceededLimit(bodySize: DataSize)
}

public class HttpRequestBody {
    public let raw: [UInt8]
    public let status: HttpRequestBodyStatus
    
    public var string: String? {
        String(bytes: raw, encoding: .utf8)
    }
    
    public var data: Data {
        Data(raw)
    }
    
    init(_ raw: [UInt8], status: HttpRequestBodyStatus = .ok) {
        self.raw = raw
        self.status = status
    }

    public func decode<T: Decodable>() throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }
}
