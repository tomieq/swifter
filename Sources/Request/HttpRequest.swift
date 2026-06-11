//
//  HttpRequest.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public enum ConnectionStrategy {
    /// the socket will remain open after serving the request
    case forceKeepAlive
    /// the socket will be closed after serving the request
    case forceCloseOnFinish
    /// the decision whether to close or keep the socket open will vary depending on the response code
    case auto
    /// the socket will be open
    case webSockets
}

public class HttpRequest {
    public let id = UUID()
    public let socketID: UUID
    public var method: HttpMethod = .unknown
    public var path: String = ""
    public var pathParams = HttpRequestParams([:])
    public var queryParams = HttpRequestParams([:])
    public lazy var formData: HttpRequestParams = {
        HttpRequestParams(self.parseUrlencodedForm())
    }()

    public lazy var multiPart: [HttpMultiPart] = {
        HttpMultiPartParser.parseMultiPartFormData(self)
    }()

    public var headers = HttpRequestHeaderParams([:])
    public var cookies = HttpRequestParams([:])
    public var body = HttpRequestBody([])
    public var clientIP: String? = ""
    public var connectionStrategy: ConnectionStrategy = .auto
    private var onFinishedClosures: [(HttpRequestSummary) -> Void] = []
    public var session: HttpSession?
    let partialSummary = HttpRequestPartialSummary()
    /// Server-provided per-request configuration: maximum WebSocket frame size.
    public var serverMaxWebSocketFrameSize: DataSize?
    private let creationTime = DispatchTime.now()

    public init(socketID: UUID) {
        self.socketID = socketID
    }

    deinit {
        let nanoTime = DispatchTime.now().uptimeNanoseconds - creationTime.uptimeNanoseconds
        let elapsedTimeInSeconds = Double(nanoTime) / 1_000_000_000
        let summary = HttpRequestSummary(requestID: self.id,
                                         socketID: self.socketID,
                                         responseCode: self.partialSummary.responseCode,
                                         responseSize: DataSize(self.partialSummary.responseSize),
                                         durationInSeconds: elapsedTimeInSeconds)
        self.onFinishedClosures.forEach { $0(summary) }
    }

    public func onFinished(_ closure: @escaping (HttpRequestSummary) -> Void) {
        self.onFinishedClosures.append(closure)
    }

    public func hasTokenForHeader(_ headerName: String, token: String) -> Bool {
        guard let headerValue = headers[headerName] else {
            return false
        }
        return headerValue.components(separatedBy: ",").filter({ $0.trimmingCharacters(in: .whitespaces).lowercased() == token }).count > 0
    }

    public func hasTokenForHeader(_ header: HttpHeader, token: String) -> Bool {
        return self.hasTokenForHeader(header.rawValue, token: token)
    }

    func parseUrlencodedForm() -> [(String, String)] {
        guard let contentTypeHeader = headers[.contentType] else {
            return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let contentType = contentTypeHeaderTokens.first, contentType == "application/x-www-form-urlencoded" else {
            return []
        }
        guard let utf8String = body.string else {
            // Consider to throw an exception here (examine the encoding from headers).
            return []
        }
        return utf8String.components(separatedBy: "&").compactMap { param -> (String, String)? in
            let tokens = param.components(separatedBy: "=")
            if let name = tokens.first?.removingPercentEncoding, let value = tokens.last?.removingPercentEncoding, tokens.count == 2 {
                return (name.replacingOccurrences(of: "+", with: " "),
                        value.replacingOccurrences(of: "+", with: " "))
            }
            return nil
        }
    }

    public var clientSupportsKeepAlive: Bool {
        if let value = self.headers[.connection] {
            return value.trimmingCharacters(in: .whitespaces).lowercased() == "keep-alive"
        }
        return false
    }
}
