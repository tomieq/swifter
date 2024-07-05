//
//  ConnectionMetrics.swift
//
//
//  Created by Tomasz on 04/07/2024.
//

import Foundation

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
    public var onOpenConnectionsChanged: ((Int) -> Void)?

    func socketOpened() {
        self.queue.async(flags: .barrier) {
            self.openSockets += 1
            self.onOpenConnectionsChanged?(self.openSockets)
        }
    }

    func socketClosed() {
        self.queue.async(flags: .barrier) {
            self.openSockets -= 1
            self.onOpenConnectionsChanged?(self.openSockets)
        }
    }
}
