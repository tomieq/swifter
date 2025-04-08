//
//  DataSize.swift
//  Swifter
//
//  Created by Tomasz on 08/04/2025.
//
import Foundation

public enum DataSize {
    private static let base: Double = 1000
    case B(Double)
    case KB(Double)
    case MB(Double)
    case GB(Double)
    case TB(Double)
    
    public init(_ bytes: Double) {
        guard bytes > 0 else {
            self = .B(0)
            return
        }
        let i = floor(log(bytes) / log(Self.base))
        let value = bytes / pow(Self.base, i)
        switch i {
        case 0:     self = .B(value)
        case 1:     self = .KB(value)
        case 2:     self = .MB(value)
        case 3:     self = .GB(value)
        default:    self = .TB(value)
        }
    }
    
    public init(_ data: Data) {
        self = .init(Double(data.count))
    }
    
    public init(_ number: Int) {
        self = .init(Double(number))
    }
    
    public init(_ number: UInt64) {
        self = .init(Double(number))
    }
    
    public var count: Int {
        switch self {
        case .B(let value):
            return Int(value)
        case .KB(let value):
            return Int(value * pow(Self.base, 1))
        case .MB(let value):
            return Int(value * pow(Self.base, 2))
        case .GB(let value):
            return Int(value * pow(Self.base, 3))
        case .TB(let value):
            return Int(value * pow(Self.base, 4))
        }
    }
}

extension DataSize: Equatable {}
extension DataSize: Comparable {}

extension DataSize: CustomStringConvertible {
    public var description: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.decimalSeparator = "."
        numberFormatter.maximumFractionDigits = 0
        
        switch self {
        case .B(let value):
            return numberFormatter.string(from: value.nsNumber)! + " B"
        case .KB(let value):
            return numberFormatter.string(from: value.nsNumber)! + " KB"
        case .MB(let value):
            numberFormatter.maximumFractionDigits = 2
            return numberFormatter.string(from: value.nsNumber)! + " MB"
        case .GB(let value):
            numberFormatter.maximumFractionDigits = 2
            return numberFormatter.string(from: value.nsNumber)! + " GB"
        case .TB(let value):
            numberFormatter.maximumFractionDigits = 2
            return numberFormatter.string(from: value.nsNumber)! + " TB"
        }
    }
}

fileprivate extension Double {
    var nsNumber: NSNumber {
        NSNumber(value: self)
    }
}
