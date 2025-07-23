//
//  HttpReposenceContent.swift
//  Swifter
//
//  Created by Tomasz Kucharski on 23/07/2025.
//


enum HttpReposenceContentType {
    case fixedSize(Int)
    case keepAlive
    case closeConection
    
    var keepSocketOpen: Bool {
        switch self {
        case .keepAlive:
            return true
        default:
            return false
        }
    }
}
typealias HttpReposenceContent = (type: HttpReposenceContentType, write: ((HttpResponseBodyWriter) throws -> Void)?)
