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
    
    @discardableResult
    public func addHeader(_ name: String, _ value: String) -> HttpResponseHeaders {
        self.storage.append((name, value))
        return self
    }
    
    @discardableResult
    public func setCookie(name: String, value: String, path: String = "/") -> HttpResponseHeaders {
        self.storage.append(("Set-Cookie", "\(name)=\(value); Path=\(path)"))
        return self
    }
    
    @discardableResult
    public func unsetCookie(name: String, path: String = "/") -> HttpResponseHeaders {
        self.storage.append(("Set-Cookie", "\(name)=; Max-Age=-99999999; Path=\(path)"))
        return self
    }
    
    @discardableResult
    public func merge(_ other: HttpResponseHeaders) -> HttpResponseHeaders {
        self.storage.append(contentsOf: other.storage)
        return self
    }
}

