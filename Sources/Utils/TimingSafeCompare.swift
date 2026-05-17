import Foundation

/// Timing-safe comparison to mitigate timing attacks when comparing secrets.
public func timingSafeEqual(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    var diff: UInt8 = 0
    for i in 0..<lhs.count {
        diff |= lhs[i] ^ rhs[i]
    }
    return diff == 0
}

public func timingSafeEqual(_ lhs: String, _ rhs: String) -> Bool {
    return timingSafeEqual(Array(lhs.utf8), Array(rhs.utf8))
}
