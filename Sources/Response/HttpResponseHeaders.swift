//
//  HttpHeaders.swift
//  
//
//  Created by Tomasz Kucharski on 08/03/2021.
//

import Foundation

public class HttpResponseHeaders {
    private var storage: [(name: String, value: String)] = []
    var raw: [(name: String, value: String)] {
        return self.storage
    }
    
    public init() {}
    
    @discardableResult
    public func addHeader(_ name: CustomStringConvertible, _ value: CustomStringConvertible) -> HttpResponseHeaders {
        self.storage.append((name.description, value.description))
        return self
    }
    
    @discardableResult
    public func addHeader(_ header: HttpHeader, _ value: CustomStringConvertible) -> HttpResponseHeaders {
        self.storage.append((header.description, value.description))
        return self
    }
    
    @discardableResult
    public func setClientCache(_ cacheTime: CacheTime) -> HttpResponseHeaders {
        var value: String {
            switch cacheTime {
            case .noCache:
                return "no-cache"
            default:
                return "max-age=\(cacheTime.rawSeconds)"
            }
        }
        self.addHeader(.cacheControl, value)
        return self
    }
    
    @discardableResult
    public func setCookie(name: String,
                          value: CustomStringConvertible,
                          path: String = "/",
                          cache: CacheTime? = nil) -> HttpResponseHeaders {
        var maxAge = ""
        if let seconds = cache?.rawSeconds {
            maxAge = " Max-Age=\(seconds);"
        }
        self.addHeader(.setCookie, "\(name)=\(value.description);\(maxAge) Path=\(path)")
        return self
    }
    
    @discardableResult
    public func unsetCookie(name: String, path: String = "/") -> HttpResponseHeaders {
        self.addHeader(.setCookie, "\(name)=; Max-Age=-99999999; Path=\(path)")
    }
    
    @discardableResult
    public func merge(_ other: HttpResponseHeaders?) -> HttpResponseHeaders {
        if let other = other {
            self.storage.append(contentsOf: other.storage)
        }
        return self
    }
}

