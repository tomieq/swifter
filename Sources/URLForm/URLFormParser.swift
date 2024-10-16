//
//  URLFormParser.swift
//
//
//  Created by Tomasz on 27/06/2024.
//

import Foundation

/// Converts `Data` to `[String: URLFormData]`.
class URLFormParser {
    /// Create a new form-urlencoded data parser.
    init() { }

    /// Default form url encoded parser.
    static let `default` = URLFormParser()

    /// Parses the data.
    /// If empty values is false, `foo=` will resolve as `foo: true`
    /// instead of `foo: ""`
    func parse(
        percentEncoded: String,
        omitEmptyValues: Bool = false,
        omitFlags: Bool = false) throws -> [String: URLFormData] {
        let partiallyDecoded = percentEncoded.replacingOccurrences(of: "+", with: " ")
        return try self.parse(data: partiallyDecoded, omitEmptyValues: omitEmptyValues, omitFlags: omitFlags)
    }

    /// Parses the data.
    /// If empty values is false, `foo=` will resolve as `foo: true`
    /// instead of `foo: ""`
    func parse(
        data: LosslessDataConvertible,
        omitEmptyValues: Bool = false,
        omitFlags: Bool = false) throws -> [String: URLFormData] {
        var encoded: [String: URLFormData] = [:]
        let data = data.convertToData()

        for pair in data.split(separator: .ampersand) {
            let data: URLFormData
            let key: URLEncodedFormEncodedKey

            /// Allow empty subsequences
            /// value= => "value": ""
            /// value => "value": true
            let token = pair.split(
                separator: .equals,
                maxSplits: 1, // max 1, `foo=a=b` should be `"foo": "a=b"`
                omittingEmptySubsequences: false)

            guard let decodedKey = try token.first?.utf8DecodedString().removingPercentEncoding else {
                throw URLFormError(
                    identifier: "percentDecoding",
                    reason: "Could not percent decode string key: \(token[0])")
            }
            let decodedValue = try token.last?.utf8DecodedString().removingPercentEncoding

            if token.count == 2 {
                if omitEmptyValues, token[1].count == 0 {
                    continue
                }
                guard let decodedValue = decodedValue else {
                    throw URLFormError(identifier: "percentDecoding", reason: "Could not percent decode string value: \(token[1])")
                }
                key = try self.parseKey(data: decodedKey)
                data = .str(decodedValue)
            } else if token.count == 1 {
                if omitFlags {
                    continue
                }
                key = try self.parseKey(data: decodedKey)
                data = "true"
            } else {
                throw URLFormError(
                    identifier: "malformedData",
                    reason: "Malformed form-urlencoded data encountered")
            }

            let resolved: URLFormData

            if !key.subKeys.isEmpty {
                var current = encoded[key.string] ?? .dictionary([:])
                self.set(&current, to: data, at: key.subKeys)
                resolved = current
            } else {
                resolved = data
            }

            encoded[key.string] = resolved
        }

        return encoded
    }

    /// Parses a `URLEncodedFormEncodedKey` from `Data`.
    private func parseKey(data dataConvertible: LosslessDataConvertible) throws -> URLEncodedFormEncodedKey {
        let data = dataConvertible.convertToData()
        let stringData: Data
        let subKeys: [URLEncodedFormEncodedSubKey]

        // check if the key has `key[]` or `key[5]`
        if data.contains(.rightSquareBracket), data.contains(.leftSquareBracket) {
            // split on the `[`
            // a[b][c][d][hello] => a, b], c], d], hello]
            let slices = data.split(separator: .leftSquareBracket)

            guard slices.count > 0 else {
                throw URLFormError(identifier: "malformedKey", reason: "Malformed form-urlencoded key encountered.")
            }
            stringData = Data(slices[0])
            subKeys = try slices[1...]
                .map { Data($0) }
                .map { data -> URLEncodedFormEncodedSubKey in
                    if data[0] == .rightSquareBracket {
                        return .array
                    } else {
                        return try .dictionary(data.dropLast().utf8DecodedString())
                    }
                }
        } else {
            stringData = data
            subKeys = []
        }

        return try URLEncodedFormEncodedKey(
            string: stringData.utf8DecodedString(),
            subKeys: subKeys)
    }

    /// Sets mutable form-urlencoded input to a value at the given `[URLEncodedFormEncodedSubKey]` path.
    private func set(_ base: inout URLFormData, to data: URLFormData, at path: [URLEncodedFormEncodedSubKey]) {
        guard path.count >= 1 else {
            base = data
            return
        }

        let first = path[0]

        var child: URLFormData
        switch path.count {
        case 1:
            child = data
        case 2...:
            switch first {
            case .array:
                /// always append to the last element of the array
                child = base.array?.last ?? .array([])
                self.set(&child, to: data, at: Array(path[1...]))
            case .dictionary(let key):
                child = base.dictionary?[key] ?? .dictionary([:])
                self.set(&child, to: data, at: Array(path[1...]))
            }
        default: fatalError()
        }

        switch first {
        case .array:
            if case .arr(var arr) = base {
                /// always append
                arr.append(child)
                base = .array(arr)
            } else {
                base = .array([child])
            }
        case .dictionary(let key):
            if case .dict(var dict) = base {
                dict[key] = child
                base = .dictionary(dict)
            } else {
                base = .dictionary([key: child])
            }
        }
    }
}

/// Represents a key in a URLEncodedForm.
private struct URLEncodedFormEncodedKey {
    let string: String
    let subKeys: [URLEncodedFormEncodedSubKey]
}

// MARK: - URLEncodedFormEncodedSubKey

/// Available subkeys.
private enum URLEncodedFormEncodedSubKey {
    case array
    case dictionary(String)
}

extension Data {
    /// UTF8 decodes a Stirng or throws an error.
    fileprivate func utf8DecodedString() throws -> String {
        guard let string = String(data: self, encoding: .utf8) else {
            throw URLFormError(identifier: "utf8Decoding", reason: "Failed to utf8 decode string: \(self)")
        }

        return string
    }
}

extension Data {
    /// Percent decodes a String or throws an error.
    private func percentDecodedString() throws -> String {
        let utf8 = try utf8DecodedString()

        guard let decoded = utf8.replacingOccurrences(of: "+", with: " ").removingPercentEncoding else {
            throw URLFormError(
                identifier: "percentDecoding",
                reason: "Failed to percent decode string: \(self)")
        }

        return decoded
    }
}

extension Array {
    /// Accesses an array index or returns `nil` if the array isn't long enough.
    fileprivate subscript(safe index: Int) -> Element? {
        guard index < count else { return nil }
        return self[index]
    }
}
