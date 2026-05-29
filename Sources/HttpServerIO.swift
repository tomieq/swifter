//
//  HttpServer.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation
import Dispatch

public protocol HttpServerIODelegate: AnyObject {
    func socketConnectionReceived(_ socket: SecureSocket)
}

open class HttpServerIO: @unchecked Sendable {
    public weak var delegate: HttpServerIODelegate?
    public var name = "Swifter"
    public var globalHeaders = HttpResponseHeaders()
    public var requestBodyLimit: RequestBodyLimit = .unlimited
    public let metrics = ConnectionMetrics()
    public var secureSocketFactory: ((Socket) -> SecureSocket?) = { DefaultSecureSocket($0) }
    /// Per-server configuration: default max WebSocket frame size.
    public var maxWebSocketFrameSize: DataSize = WebSocketSession.defaultMaxFrameSize
    /// Per-server socket send/receive timeout (seconds).
    public var socketTimeoutSeconds: Int = 60
    /// Maximum number of request headers allowed per request. Protects against
    /// header-flood attacks. Default: 100.
    public var maxRequestHeaderCount: Int = 100
    let instantRequestHandler = HttpInstantResponseHandler()
    public var globalErrorHandler: HttpGlobalErrorHandler? {
        set {
            self.instantRequestHandler.errorHandler = newValue
        }
        get { return nil }
    }

    private var socket = Socket(socketFileDescriptor: -1)
    private var sockets = Set<Socket>()

    public enum HttpServerIOState: Int32 {
        case starting
        case running
        case stopping
        case stopped
    }

    private let stateLock = NSLock()
    private var stateValue: Int32 = HttpServerIOState.stopped.rawValue

    public private(set) var state: HttpServerIOState {
        get {
            self.stateLock.lock()
            defer { self.stateLock.unlock() }
            return HttpServerIOState(rawValue: self.stateValue)!
        }
        set(state) {
            self.stateLock.lock()
            self.stateValue = state.rawValue
            self.stateLock.unlock()
        }
    }

    public var operating: Bool { return self.state == .running }

    /// String representation of the IPv4 address to receive requests from.
    /// It's only used when the server is started with `forceIPv4` option set to true.
    /// Otherwise, `listenAddressIPv6` will be used.
    public var listenAddressIPv4: String?

    /// String representation of the IPv6 address to receive requests from.
    /// It's only used when the server is started with `forceIPv4` option set to false.
    /// Otherwise, `listenAddressIPv4` will be used.
    public var listenAddressIPv6: String?

    private let queue = DispatchQueue(label: "swifter.httpserverio.clientsockets")

    public var port: Int {
        get throws {
            return Int(try self.socket.port)
        }
    }

    public func isIPv4() throws -> Bool {
        return try self.socket.isIPv4()
    }

    public func close(socketID: UUID) {
        self.sockets.first { $0.id == socketID }?.close()
    }

    deinit {
        stop()
    }

    @available(macOS 10.15, iOS 13.0, *)
    public func start(_ port: in_port_t = 8080, forceIPv4: Bool = false, priority: DispatchQoS.QoSClass = DispatchQoS.QoSClass.background) throws {
        guard !self.operating else { return }
        let queuePriority = QueuePriority(priority)
        self.stop()
        self.state = .starting
        let address = forceIPv4 ? self.listenAddressIPv4 : self.listenAddressIPv6
        self.socket = try Socket.tcpSocketForListen(port, forceIPv4, SOMAXCONN, address)
        try self.socket.setNonBlocking()
        self.state = .running
        Task.detached(priority: queuePriority.taskPriority) { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.operating else { return }
            while strongSelf.operating {
                do {
                    let socket = try await strongSelf.socket.acceptClientSocketAsync()
                    Task.detached(priority: queuePriority.taskPriority) { [weak self] in
                        guard let strongSelf = self else { return }
                        guard strongSelf.operating else { return }
                        strongSelf.queue.sync {
                            _ = strongSelf.sockets.insert(socket)
                        }
                        strongSelf.metrics.notify(.connected(socketID: socket.id))
                        await strongSelf.handleConnectionAsync(socket)
                        strongSelf.metrics.notify(.disconnected(socketID: socket.id))
                        strongSelf.queue.sync {
                            _ = strongSelf.sockets.remove(socket)
                        }
                    }
                } catch {
                    guard let strongSelf = self else { return }
                    if strongSelf.operating {
                        print("Failed to accept client socket: \(error)")
                        try? await Task.sleep(nanoseconds: 1_000_000)
                        continue
                    }
                    break
                }
            }
            strongSelf.stop()
        }
    }

    private final class QueuePriority: @unchecked Sendable {
        let value: DispatchQoS.QoSClass

        init(_ value: DispatchQoS.QoSClass) {
            self.value = value
        }

        var taskPriority: TaskPriority {
            switch self.value {
            case .background, .utility:
                return .medium
            case .userInitiated, .userInteractive:
                return .high
            default:
                return .medium
            }
        }
    }

    public func stop() {
        guard self.operating else { return }
        self.state = .stopping
        self.queue.sync {
            // Shutdown connected peers because they can live in 'keep-alive' or 'websocket' loops.
            for socket in self.sockets {
                socket.close()
            }
            self.sockets.removeAll(keepingCapacity: true)
        }
        self.socket.close()
        self.state = .stopped
    }

    open func dispatch(_ request: HttpRequest, _ responseHeaders: HttpResponseHeaders) async -> ([String: String], HttpRequestHandler) {
        return ([:], { _, _ in HttpResponse.notFound() })
    }

    private func handleConnectionAsync(_ socket: Socket) async {
        socket.setTimeouts(seconds: self.socketTimeoutSeconds)

        guard let tlsSocket = secureSocketFactory(socket) else {
            print("Closing connection. SecureSocket in nil")
            socket.close()
            return
        }

        let parser = HttpParser(bodyLimit: requestBodyLimit, maxHeadersCount: self.maxRequestHeaderCount)
        while self.operating {
            var request: HttpRequest
            do {
                request = try await parser.readHttpRequest(tlsSocket)
            } catch HttpParserError.uriTooLong {
                await self.sendErrorAndCloseAsync(tlsSocket, .uriTooLong())
                break
            } catch HttpParserError.headersTooLarge {
                await self.sendErrorAndCloseAsync(tlsSocket, .requestHeaderFieldsTooLarge())
                break
            } catch HttpParserError.negativeContentLength {
                await self.sendErrorAndCloseAsync(tlsSocket, .badRequest())
                break
            } catch HttpParserError.invalidChunkSize, HttpParserError.unsupportedTransferEncoding {
                await self.sendErrorAndCloseAsync(tlsSocket, .badRequest())
                break
            } catch {
                break
            }

            request.serverMaxWebSocketFrameSize = self.maxWebSocketFrameSize
            self.metrics.notify(.traffic(socketID: socket.id))
            let responseHeaders = HttpResponseHeaders()
            let response = await self.executeHandlerAsync(request, responseHeaders)
            request.partialSummary.responseCode = response.statusCode
            var keepConnection = false
            do {
                if self.operating {
                    keepConnection = try await self.respondAsync(tlsSocket,
                                                                 request: request,
                                                                 response: response,
                                                                 customHeaders: responseHeaders)
                }
            } catch {
                print("Failed to send response: \(error)")
                break
            }
            if let session = response.socketSession() {
                self.delegate?.socketConnectionReceived(tlsSocket)
                self.metrics.notify(.webSocketSessionStarted(socketID: socket.id))
                await session(tlsSocket)
                break
            }
            if !keepConnection { break }
        }
        tlsSocket.close()
    }

    private func sendErrorAndCloseAsync(_ socket: SecureSocket, _ response: HttpResponse) async {
        let fakeReq = HttpRequest(socketID: socket.id)
        fakeReq.connectionStrategy = .forceCloseOnFinish
        _ = try? await self.respondAsync(socket,
                                         request: fakeReq,
                                         response: response,
                                         customHeaders: HttpResponseHeaders())
    }

    private func executeHandlerAsync(_ request: HttpRequest,
                                     _ headers: HttpResponseHeaders) async -> HttpResponse {
        let (params, handler) = await self.dispatch(request, headers)
        request.pathParams = HttpRequestParams(params)
        return await self.instantRequestHandler.watch(request, headers, handler)
    }

    private struct InnerWriteContext: HttpResponseBodyWriter {
        let socket: SecureSocket

        func write(_ file: String.File) async throws {
            try await self.socket.writeFile(file)
        }

        func write(_ data: [UInt8]) async throws {
            try await self.write(ArraySlice(data))
        }

        func write(_ data: ArraySlice<UInt8>) async throws {
            try await self.socket.writeUInt8(data)
        }

        func write(_ data: NSData) async throws {
            try await self.socket.writeData(data)
        }

        func write(_ data: Data) async throws {
            try await self.socket.writeData(data)
        }
    }

    private func respondAsync(_ socket: SecureSocket,
                              request: HttpRequest,
                              response: HttpResponse,
                              customHeaders: HttpResponseHeaders) async throws -> Bool {
        guard self.operating else { return false }

        var responseHeader = String()

        responseHeader.append("HTTP/1.1 \(response.statusCode) \(response.reasonPhrase)\r\n")

        let packet = response.packet()

        if case .fixedSize(let length) = packet.rawBody?.length {
            responseHeader.append("Content-Length: \(length)\r\n")
        }

        let keepAlive = self.shouldKeepConnectionAlive(request: request, packet: packet)
        if keepAlive {
            responseHeader.append("Connection: keep-alive\r\n")
        } else {
            responseHeader.append("Connection: close\r\n")
        }

        var sendHeaders = [String]()
        customHeaders.raw.forEach { header in
            responseHeader.append("\(header.name): \(header.value)\r\n")
            sendHeaders.append(header.name.lowercased())
        }
        response.responseHeaders.raw.forEach { header in
            if !sendHeaders.contains(header.name.lowercased()) {
                responseHeader.append("\(header.name): \(header.value)\r\n")
            }
        }
        self.globalHeaders.raw.forEach { header in
            if !sendHeaders.contains(header.name.lowercased()) {
                responseHeader.append("\(header.name): \(header.value)\r\n")
            }
        }
        if !sendHeaders.contains("Server".lowercased()) {
            responseHeader.append("Server: \(self.name)\r\n")
        }
        responseHeader.append("\r\n")

        socket.raw.transferCounter.startCounting()
        defer {
            request.partialSummary.responseSize = socket.raw.transferCounter.transfer
        }
        try await socket.writeUTF8(responseHeader)

        if let writeClosure = packet.rawBody?.write {
            let context = InnerWriteContext(socket: socket)
            try await writeClosure(context)
        }
        return keepAlive
    }

    private func shouldKeepConnectionAlive(request: HttpRequest, packet: HttpResponsePacket) -> Bool {
        guard request.clientSupportsKeepAlive else {
            return false
        }
        switch request.connectionStrategy {
        case .forceKeepAlive:
            return true
        case .forceCloseOnFinish:
            return false
        case .auto:
            switch packet.connection {
            case .keepAlive:
                return true
            case .closeConection:
                return false
            }
        }
    }
}
