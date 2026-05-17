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

    private var stateValue: Int32 = HttpServerIOState.stopped.rawValue

    public private(set) var state: HttpServerIOState {
        get {
            return HttpServerIOState(rawValue: self.stateValue)!
        }
        set(state) {
            #if !os(Linux)
            OSAtomicCompareAndSwapInt(self.state.rawValue, state.rawValue, &self.stateValue)
            #else
            self.stateValue = state.rawValue
            #endif
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
        self.state = .running
        DispatchQueue.global(qos: queuePriority.value).async { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.operating else { return }
            while let socket = try? strongSelf.socket.acceptClientSocket() {
                DispatchQueue.global(qos: queuePriority.value).async { [weak self] in
                    guard let strongSelf = self else { return }
                    guard strongSelf.operating else { return }
                    strongSelf.queue.sync {
                        _ = strongSelf.sockets.insert(socket)
                    }
                    strongSelf.metrics.notify(.connected(socketID: socket.id))
                    strongSelf.handleConnection(socket)
                    strongSelf.metrics.notify(.disconnected(socketID: socket.id))
                    strongSelf.queue.sync {
                        _ = strongSelf.sockets.remove(socket)
                    }
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

    private func handleConnection(_ socket: Socket) {
        // Apply per-server socket timeouts before wrapping the socket.
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
                request = try parser.readHttpRequest(tlsSocket)
            } catch HttpParserError.uriTooLong {
                self.sendErrorAndClose(tlsSocket, .uriTooLong())
                break
            } catch HttpParserError.headersTooLarge {
                self.sendErrorAndClose(tlsSocket, .requestHeaderFieldsTooLarge())
                break
            } catch HttpParserError.negativeContentLength {
                self.sendErrorAndClose(tlsSocket, .badRequest())
                break
            } catch HttpParserError.invalidChunkSize, HttpParserError.unsupportedTransferEncoding {
                self.sendErrorAndClose(tlsSocket, .badRequest())
                break
            } catch {
                // Any other parse error: close the connection silently.
                break
            }

            // Provide server config to handlers (so websocket() can pick up config)
            request.serverMaxWebSocketFrameSize = self.maxWebSocketFrameSize
            self.metrics.notify(.traffic(socketID: socket.id))
            let responseHeaders = HttpResponseHeaders()
            let response = self.executeHandler(request, responseHeaders)
            request.partialSummary.responseCode = response.statusCode
            var keepConnection = false
            do {
                if self.operating {
                    keepConnection = try self.respond(tlsSocket,
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
                session(tlsSocket)
                break
            }
            if !keepConnection { break }
        }
        tlsSocket.close()
    }

    private func sendErrorAndClose(_ socket: SecureSocket, _ response: HttpResponse) {
        let fakeReq = HttpRequest(socketID: socket.id)
        fakeReq.connectionStrategy = .forceCloseOnFinish
        _ = try? self.respond(socket,
                              request: fakeReq,
                              response: response,
                              customHeaders: HttpResponseHeaders())
    }

    /// Bridges the synchronous, blocking connection loop into the async handler pipeline.
    ///
    /// The connection loop runs on a dedicated `DispatchQueue.global` worker which performs
    /// blocking socket I/O. User handlers, however, are `async`. We launch a detached Task on
    /// the cooperative pool, then block the dispatch worker on a semaphore until the async
    /// pipeline completes. This avoids polluting the cooperative pool with blocking I/O while
    /// still allowing handlers to suspend freely.
    private func executeHandler(_ request: HttpRequest,
                                _ headers: HttpResponseHeaders) -> HttpResponse {
        let semaphore = DispatchSemaphore(value: 0)
        let box = HandlerResponseBox()
        // `HttpRequest` and `HttpResponseHeaders` are reference types not declared `Sendable`,
        // but each request flows through exactly one handler chain at a time. The semaphore
        // establishes a happens-before relationship between the writes inside the detached
        // task and the read on the connection thread, so transferring them across the
        // boundary inside `UnsafeTransfer` is safe in practice.
        let transfer = UnsafeTransfer(request: request, headers: headers)
        Task.detached(priority: .userInitiated) { [self] in
            defer { semaphore.signal() }
            let request = transfer.request
            let headers = transfer.headers
            let (params, handler) = await self.dispatch(request, headers)
            request.pathParams = HttpRequestParams(params)
            let response = await self.instantRequestHandler.watch(request, headers, handler)
            box.store(response)
        }
        semaphore.wait()
        return box.load() ?? .internalServerError(.text("Unexpected handler execution failure"))
    }

    private struct UnsafeTransfer: @unchecked Sendable {
        let request: HttpRequest
        let headers: HttpResponseHeaders
    }

    private final class HandlerResponseBox: @unchecked Sendable {
        private let lock = NSLock()
        private var response: HttpResponse?

        func store(_ response: HttpResponse) {
            self.lock.lock()
            self.response = response
            self.lock.unlock()
        }

        func load() -> HttpResponse? {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.response
        }
    }

    private struct InnerWriteContext: HttpResponseBodyWriter {
        let socket: SecureSocket

        func write(_ file: String.File) throws {
            try self.socket.writeFile(file)
        }

        func write(_ data: [UInt8]) throws {
            try self.write(ArraySlice(data))
        }

        func write(_ data: ArraySlice<UInt8>) throws {
            try self.socket.writeUInt8(data)
        }

        func write(_ data: NSData) throws {
            try self.socket.writeData(data)
        }

        func write(_ data: Data) throws {
            try self.socket.writeData(data)
        }
    }

    private func respond(_ socket: SecureSocket,
                         request: HttpRequest,
                         response: HttpResponse,
                         customHeaders: HttpResponseHeaders) throws -> Bool {
        guard self.operating else { return false }

        // Some web-socket clients (like Jetfire) expects to have header section in a single packet.
        // We can't promise that but make sure we invoke "write" only once for response header section.

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

        // combine auto-headers and overwitten by handler
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
        try socket.writeUTF8(responseHeader)

        if let writeClosure = packet.rawBody?.write {
            let context = InnerWriteContext(socket: socket)
            try writeClosure(context)
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
