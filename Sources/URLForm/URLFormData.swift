//
//  URLFormData.swift
//
//
//  Created by Tomasz on 27/06/2024.
//

import Foundation

enum URLFormData: Equatable {
    case dict([String: URLFormData])
    case str(String)
    case arr([URLFormData])
}

extension URLFormData: NestedData {
    var string: String? {
        switch self {
        case .str(let item): return item
        default: return .none
        }
    }

    var url: URL? {
        switch self {
        case .str(let item): return .init(string: item)
        default: return .none
        }
    }

    var array: [URLFormData]? {
        switch self {
        case .arr(let list): return list
        default: return .none
        }
    }

    var dictionary: [String: URLFormData]? {
        switch self {
        case .dict(let map): return map
        default: return .none
        }
    }

    static func dictionary(_ value: [String: URLFormData]) -> URLFormData {
        .dict(value)
    }

    static func array(_ value: [URLFormData]) -> URLFormData {
        .arr(value)
    }
}

extension URLFormData: ExpressibleByArrayLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral {
    init(arrayLiteral elements: URLFormData...) {
        self = .arr(elements)
    }

    init(stringLiteral value: String) {
        self = .str(value)
    }

    init(dictionaryLiteral elements: (String, URLFormData)...) {
        self = .dict(elements.reduce([:]) { curr, next in
            curr.merging([next.0: next.1]) { $1 }
        })
    }
}
