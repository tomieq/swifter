import Foundation

extension UInt64 {
    public var readableSizeWithUnit: String {
        DataSize(self).description
    }
}
