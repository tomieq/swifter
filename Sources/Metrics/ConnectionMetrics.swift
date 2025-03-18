//
//  ConnectionMetrics.swift
//
//
//  Created by Tomasz on 04/07/2024.
//

import Foundation

public class ConnectionMetrics {
    enum SocketAction {
        case opened
        case closed
        
        var diff: Int {
            switch self {
            case .opened:
                return 1
            case .closed:
                return -1
            }
        }
    }
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

    func socket(_ action: SocketAction) {
        self.queue.async(flags: .barrier) {
            self.openSockets += action.diff
            let newValue = self.openSockets
            DispatchQueue.global().async {
                self.onOpenConnectionsChanged?(newValue)
            }
        }
    }
}
