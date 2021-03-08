//
//  HttpHeaders.swift
//  
//
//  Created by Tomasz Kucharski on 08/03/2021.
//

import Foundation

public class HttpHeaders {
    private var storage: [(name: String, value: String)] = []
    var raw: [(name: String, value: String)] {
        return self.storage
    }
    
    @discardableResult
    func addHeader(_ name: String, _ value: String) -> HttpHeaders {
        self.storage.append((name, value))
        return self
    }
    
    @discardableResult
    func setCookie(name: String, value: String) -> HttpHeaders {
        self.storage.append(("Set-Cookie", "\(name)=\(value)"))
        return self
    }
    
    @discardableResult
    func unsetCookie(name: String) -> HttpHeaders {
        self.storage.append(("Set-Cookie", "\(name)=; Max-Age=-99999999"))
        return self
    }
}

