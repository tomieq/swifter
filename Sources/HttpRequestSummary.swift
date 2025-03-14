//
//  HttpRequestSummary.swift
//
//
//  Created by Tomasz on 16/11/2024.
//

import Foundation

public struct HttpRequestSummary {
    public let requestID: UUID
    public let responseCode: Int
    public let responseSizeInBytes: UInt64
    public let durationInSeconds: Double
}

final class HttpRequestPartialSummary {
    var responseCode: Int = 0
    var responseSize: UInt64 = 0
}
