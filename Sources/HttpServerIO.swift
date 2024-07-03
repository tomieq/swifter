//
//  HttpServer.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation
import Dispatch

public protocol HttpServerIODelegate: AnyObject {
    func socketConnectionReceived(_ socket: Socket)
}

open class HttpServerIO {

    public weak var delegate: HttpServerIODelegate?
    public var name = "Swifter"
    public var globalHeaders = HttpResponseHeaders()

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
            return HttpServerIOState(rawValue: stateValue)!
        }
        set(state) {
            #if !os(Linux)
            OSAtomicCompareAndSwapInt(self.state.rawValue, state.rawValue, &stateValue)
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

    public func port() throws -> Int {
        return Int(try socket.port())
    }

    public func isIPv4() throws -> Bool {
        return try socket.isIPv4()
    }

    deinit {
        stop()
    }

    @available(macOS 10.10, *)
    public func start(_ port: in_port_t = 8080, forceIPv4: Bool = false, priority: DispatchQoS.QoSClass = DispatchQoS.QoSClass.background) throws {
        guard !self.operating else { return }
        stop()
        self.state = .starting
        let address = forceIPv4 ? listenAddressIPv4 : listenAddressIPv6
        self.socket = try Socket.tcpSocketForListen(port, forceIPv4, SOMAXCONN, address)
        self.state = .running
        DispatchQueue.global(qos: priority).async { [weak self] in
            guard let strongSelf = self else { return }
            guard strongSelf.operating else { return }
            while let socket = try? strongSelf.socket.acceptClientSocket() {
                DispatchQueue.global(qos: priority).async { [weak self] in
                    guard let strongSelf = self else { return }
                    guard strongSelf.operating else { return }
                    strongSelf.queue.async {
                        strongSelf.sockets.insert(socket)
                    }

                    strongSelf.handleConnection(socket)

                    strongSelf.queue.async {
                        strongSelf.sockets.remove(socket)
                    }
                }
            }
            strongSelf.stop()
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
        socket.close()
        self.state = .stopped
    }

    open func dispatch(_ request: HttpRequest, _ responseHeaders: HttpResponseHeaders) -> ([String: String], HttpRequestHandler) {
        return ([:], { _, _ in HttpResponse.notFound() })
    }

    private func handleConnection(_ socket: Socket) {
        let parser = HttpParser()
        while self.operating, let request = try? parser.readHttpRequest(socket) {
            let request = request
            let responseHeaders = HttpResponseHeaders()
            request.address = try? socket.peername()
            let (params, handler) = self.dispatch(request, responseHeaders)
            request.pathParams = HttpRequestParams(params)
            let response = HttpInstantResponseHandler.watch(request, responseHeaders, handler)
            request.responseCode = response.statusCode
            var keepConnection = request.clientSupportsKeepAlive()
            if request.disableKeepAlive {
                keepConnection = false
            }

            do {
                if self.operating {
                    keepConnection = try self.respond(socket, response: response, customHeaders: responseHeaders, keepAlive: keepConnection)
                }
            } catch {
                print("Failed to send response: \(error)")
            }
            if let session = response.socketSession() {
                delegate?.socketConnectionReceived(socket)
                session(socket)
                break
            }
            if !keepConnection { break }
        }
        socket.close()
    }

    private struct InnerWriteContext: HttpResponseBodyWriter {

        let socket: Socket

        func write(_ file: String.File) throws {
            try socket.writeFile(file)
        }

        func write(_ data: [UInt8]) throws {
            try write(ArraySlice(data))
        }

        func write(_ data: ArraySlice<UInt8>) throws {
            try socket.writeUInt8(data)
        }

        func write(_ data: NSData) throws {
            try socket.writeData(data)
        }

        func write(_ data: Data) throws {
            try socket.writeData(data)
        }
    }

    private func respond(_ socket: Socket, response: HttpResponse, customHeaders: HttpResponseHeaders, keepAlive: Bool) throws -> Bool {
        guard self.operating else { return false }

        // Some web-socket clients (like Jetfire) expects to have header section in a single packet.
        // We can't promise that but make sure we invoke "write" only once for response header section.

        var responseHeader = String()

        responseHeader.append("HTTP/1.1 \(response.statusCode) \(response.reasonPhrase)\r\n")

        let content = response.content()

        if content.length >= 0 {
            responseHeader.append("Content-Length: \(content.length)\r\n")
        }

        if keepAlive && content.length != -1 {
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
        response.autoHeaders().raw.forEach { header in
            if !sendHeaders.contains(header.name.lowercased()) {
                responseHeader.append("\(header.name): \(header.value)\r\n")
            }
        }
        self.globalHeaders.addHeader("Server", self.name)
        self.globalHeaders.raw.forEach { header in
            if !sendHeaders.contains(header.name.lowercased()) {
                responseHeader.append("\(header.name): \(header.value)\r\n")
            }
        }

        responseHeader.append("\r\n")

        try socket.writeUTF8(responseHeader)

        if let writeClosure = content.write {
            let context = InnerWriteContext(socket: socket)
            try writeClosure(context)
        }

        return keepAlive && content.length != -1
    }
}
