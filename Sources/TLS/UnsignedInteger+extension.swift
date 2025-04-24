//
//  UnsignedInteger+extension.swift
//  Swifter
//
//  Created by Tomasz on 23/04/2025.
//

extension UnsignedInteger where Self : FixedWidthInteger {
    init?<T : RandomAccessCollection>(bigEndianBytes: T) where T.Element == UInt8, T.Index == Int {
        guard bigEndianBytes.count <= Self.bitWidth / 8 else {
            return nil
        }
        self = bigEndianBytes.reduce(0 as Self, { $0 << 8 | Self($1)})
    }
    
    var bigEndianBytes: [UInt8] {
        let bitWidth = type(of: self).bitWidth
        
        var bytes = [UInt8]()
        var shift = bitWidth
        var mask  = Self(0xff) << (shift - 8)
        
        for _ in 0..<bitWidth / 8 {
            shift -= 8
            bytes.append(UInt8((self & mask) >> shift))
            mask = mask >> 8
        }
        return bytes
    }
}
