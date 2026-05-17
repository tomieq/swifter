//
//  ConnectionLifetimeGuard.swift
//  Swifter
//
//  Created by Tomasz Kucharski on 23/07/2025.
//
import Foundation
import Dispatch

public class ConnectionLifetimeGuard: @unchecked Sendable {
    let server: HttpServer
    let socketLifeTime: TimeInterval
    var socketActivity = ThreadSafeCache<UUID, Date>()

    public init(server: HttpServer, socketLifeTime: TimeInterval = 10) {
        self.server = server
        self.socketLifeTime = socketLifeTime
        server.metrics.subscribers.append({ [weak self] change in
            switch change.event {
            case .connected(let socketID), .traffic(let socketID):
                self?.socketActivity[socketID] = Date()
            case .disconnected(let socketID), .webSocketSessionStarted(let socketID):
                self?.socketActivity[socketID] = nil
            }
        })
        self.schedulePruning()
    }

    func pruneStaleSockets() {
        let staleSockets = self.socketActivity.all
            .filter { $0.value < Date().addingTimeInterval(-1 * self.socketLifeTime) }
            .map { $0.key }
        for socketID in staleSockets {
            self.server.close(socketID: socketID)
        }
    }

    func schedulePruning() {
        DispatchQueue.global().asyncAfter(deadline: .now() + self.socketLifeTime) {
            self.pruneStaleSockets()
            self.schedulePruning()
        }
    }
}
