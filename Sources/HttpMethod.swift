//
//  HttpMethod.swift
//  
//
//  Created by Tomasz Kucharski on 08/03/2021.
//

import Foundation


public enum HttpMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
    case HEAD
    case unknown
    
    init?(_ name: String) {
        self.init(rawValue: name.uppercased())
    }
}
