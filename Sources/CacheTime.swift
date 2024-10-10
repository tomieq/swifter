//
//  CacheTime.swift
//  Swifter
//
//  Created by Tomasz on 10/10/2024.
//

public enum CacheTime {
    case none
    case seconds(Int)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    
    var rawSeconds: Int {
        switch self {
        case .none:
            return 0
        case .seconds(let value):
            return value
        case .minutes(let value):
            return value * 60
        case .hours(let value):
            return value * 3600
        case .days(let value):
            return value * 86400
        }
    }
}
