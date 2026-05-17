//
//  ConnectionMetrics.swift
//
//
//  Created by Tomasz on 04/07/2024.
//

import Foundation

public enum ConnectionEvent: Sendable {
    case connected(socketID: UUID)
    case traffic(socketID: UUID)
    case webSocketSessionStarted(socketID: UUID)
    case disconnected(socketID: UUID)

    var diff: Int {
        switch self {
        case .connected:
            return 1
        case .disconnected:
            return -1
        default:
            return 0
        }
    }
}

extension ConnectionEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connected(let socketID):
            return "Connected socket \(socketID)"
        case .disconnected(let socketID):
            return "Disconnected socket \(socketID)"
        case .traffic(let socketID):
            return "Traffic on socket \(socketID)"
        case .webSocketSessionStarted(let socketID):
            return "WebSocketSessionStarted on socket \(socketID)"
        }
    }
}

public struct ConnectionChange: Sendable {
    public let openConnections: Int
    public let event: ConnectionEvent
}

public typealias ConnectionChangeHandler = @Sendable (ConnectionChange) -> Void
public class ConnectionMetrics: @unchecked Sendable {
    private let accessQueue = DispatchQueue(label: "swifter.metrics.queue", attributes: .concurrent)
    private let notificationQueue = DispatchQueue(label: "swifter.metrics.queue")
    private var openSockets = 0
    public var openConnections: Int {
        get {
            self.accessQueue.sync {
                self.openSockets
            }
        }
    }

    public var subscribers: [ConnectionChangeHandler] = []

    func notify(_ event: ConnectionEvent) {
        self.accessQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.openSockets += event.diff
            let newValue = self.openSockets
            if !self.subscribers.isEmpty {
                self.notificationQueue.async { [unowned self] in
                    let notification = ConnectionChange(openConnections: newValue, event: event)
                    for listener in self.subscribers {
                        listener(notification)
                    }
                }
            }
        }
    }
}
