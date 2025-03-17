//
//  ThreadSafeCache.swift
//  Swifter
//
//  Created by Tomasz on 17/03/2025.
//

import Foundation
import Dispatch

public class ThreadSafeCache<K: Hashable,V> {
    private let queue = DispatchQueue(label: "com.dispatchBarrier.\(UUID())", attributes: .concurrent)
    private var cache: [K:V] = [:]
    
    public init() {}
    
    public var all: [K:V] {
        get {
            queue.sync {
                cache
            }
        }
    }
    
    public subscript(index: K) -> V? {
        get {
            queue.sync {
                cache[index]
            }
        }
        set(newValue) {
            queue.sync(flags: .barrier) {
                self.cache[index] = newValue
            }
        }
    }
    
    public subscript(index: K, default value: V) -> V? {
        get {
            queue.sync {
                cache[index, default: value]
            }
        }
        set(newValue) {
            queue.sync(flags: .barrier) {
                self.cache[index] = newValue
            }
        }
    }
}
