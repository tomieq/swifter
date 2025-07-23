//
//  ConnectionMetrics.swift
//
//
//  Created by Tomasz on 04/07/2024.
//

import Foundation

public enum ConnectionEvent {
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
        default :
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

public struct ConnectionChange {
    public let openConnections: Int
    public let event: ConnectionEvent
}

public class ConnectionMetrics {
    private let queue = DispatchQueue(label: "swifter.metrics.queue", attributes: .concurrent)
    private var openSockets = 0
    public var openConnections: Int {
        get {
            self.queue.sync {
                openSockets
            }
        }
    }
    public var onConnectionChange: ((ConnectionChange) -> Void)?

    func notify(_ event: ConnectionEvent) {
        self.queue.async(flags: .barrier) {
            self.openSockets += event.diff
            let newValue = self.openSockets
            if let onConnectionChange = self.onConnectionChange {
                DispatchQueue.global().async {
                    onConnectionChange(ConnectionChange(openConnections: newValue, event: event))
                }
            }
        }
    }
}
