import Foundation

extension UInt64 {
    public var readableSizeWithUnit: String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useAll] // optional: restricts the units to MB only
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(self))
    }
}
