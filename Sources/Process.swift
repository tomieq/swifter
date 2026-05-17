//
//  Process
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public class Process {
    private final class SignalState: @unchecked Sendable {
        private let lock = NSLock()
        private var watchers = [(Int32) -> Void]()
        private var observed = false

        func register(_ callback: @escaping (Int32) -> Void) -> Bool {
            self.lock.lock()
            defer { self.lock.unlock() }
            let shouldInstallHandlers = !self.observed
            self.observed = true
            self.watchers.append(callback)
            return shouldInstallHandlers
        }

        func notify(_ signum: Int32) {
            self.lock.lock()
            let watchers = self.watchers
            self.lock.unlock()
            watchers.forEach { $0(signum) }
        }
    }

    public static var pid: Int {
        return Int(getpid())
    }

    public static var tid: UInt64 {
        #if os(Linux)
        return UInt64(pthread_self())
        #else
        var tid: __uint64_t = 0
        pthread_threadid_np(nil, &tid)
        return UInt64(tid)
        #endif
    }

    private static let signalState = SignalState()

    public static func watchSignals(_ callback: @escaping (Int32) -> Void) {
        if self.signalState.register(callback) {
            [SIGTERM, SIGHUP, SIGSTOP, SIGINT].forEach { item in
                signal(item) { signum in
                    Process.signalState.notify(signum)
                }
            }
        }
    }
}
