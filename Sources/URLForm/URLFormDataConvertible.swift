//
//  URLFormDataConvertible.swift
//
//
//  Created by Tomasz on 27/06/2024.
//

import Foundation

protocol URLFormDataConvertible {
    func convertToURLEncodedFormData() throws -> URLFormData
    static func convertFromURLEncodedFormData(_ data: URLFormData) throws -> Self
}

extension String: URLFormDataConvertible {
    static func convertFromURLEncodedFormData(_ data: URLFormData) throws -> String {
        guard let string = data.string else {
            throw URLFormError(identifier: "url", reason: "Could not convert to `String`: \(data)")
        }
        return string
    }

    func convertToURLEncodedFormData() throws -> URLFormData {
        .str(self)
    }
}

extension URL: URLFormDataConvertible {
    static func convertFromURLEncodedFormData(_ data: URLFormData) throws -> URL {
        guard let url = data.url else {
            throw URLFormError(identifier: "url", reason: "Could not convert to `URL`: \(data)")
        }
        return url
    }

    func convertToURLEncodedFormData() throws -> URLFormData {
        .str(absoluteString)
    }
}

extension FixedWidthInteger {
    static func convertFromURLEncodedFormData(_ data: URLFormData) throws -> Self {
        guard let fwi = data.string.flatMap(Self.init) else {
            throw URLFormError(identifier: "fwi", reason: "Could not convert to `\(Self.self)`: \(data)")
        }
        return fwi
    }

    func convertToURLEncodedFormData() throws -> URLFormData {
        .str(description)
    }
}

extension Int: URLFormDataConvertible { }

extension Int8: URLFormDataConvertible { }

extension Int16: URLFormDataConvertible { }

extension Int32: URLFormDataConvertible { }

extension Int64: URLFormDataConvertible { }

extension UInt: URLFormDataConvertible { }

extension UInt8: URLFormDataConvertible { }

extension UInt16: URLFormDataConvertible { }

extension UInt32: URLFormDataConvertible { }

extension UInt64: URLFormDataConvertible { }

extension BinaryFloatingPoint {
    static func convertFromURLEncodedFormData(_ data: URLFormData) throws -> Self {
        guard let bfp = data.string.flatMap(Double.init).flatMap(Self.init) else {
            throw URLFormError(identifier: "bfp", reason: "Could not convert to `\(Self.self)`: \(data)")
        }

        return bfp
    }

    func convertToURLEncodedFormData() throws -> URLFormData {
        .str("\(self)")
    }
}

extension Float: URLFormDataConvertible { }

extension Double: URLFormDataConvertible { }

extension Bool: URLFormDataConvertible {
    static func convertFromURLEncodedFormData(_ data: URLFormData) throws -> Bool {
        guard let bool = data.string?.bool else {
            throw URLFormError(identifier: "bfp", reason: "Could not convert to `\(Self.self)`: \(data)")
        }
        return bool
    }

    func convertToURLEncodedFormData() throws -> URLFormData {
        .str(description)
    }
}

extension Decimal: URLFormDataConvertible {
    static func convertFromURLEncodedFormData(_ data: URLFormData) throws -> Decimal {
        guard let string = data.string, let d = Decimal(string: string) else {
            throw URLFormError(identifier: "decimal", reason: "Could not convert to Decimal: \(data)")
        }
        return d
    }

    func convertToURLEncodedFormData() throws -> URLFormData {
        .str(description)
    }
}

extension String {
    /// Converts the string to a `Bool` or returns `nil`.
    fileprivate var bool: Bool? {
        switch lowercased() {
        case "true", "yes", "1", "y": return true
        case "false", "no", "0", "n": return false
        default: return nil
        }
    }
}
