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
    public func setCookie(name: String, value: String) -> HttpResponseHeaders {
        self.storage.append(("Set-Cookie", "\(name)=\(value)"))
        return self
    }
    
    @discardableResult
    public func unsetCookie(name: String) -> HttpResponseHeaders {
        self.storage.append(("Set-Cookie", "\(name)=; Max-Age=-99999999"))
        return self
    }
}

