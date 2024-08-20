//
//  URLFormDecoder.swift
//
//
//  Created by Tomasz on 27/06/2024.
//

import Foundation

public class URLFormDecoder {
    private let parser: URLFormParser

    /// If `true`, empty values will be omitted. Empty values are URL-Encoded keys with no value following the `=` sign.
    ///     name=John&age=
    /// In the above example, `age` is an empty value.
    public var omitEmptyValues: Bool

    /// If `true`, flags will be omitted. Flags are URL-encoded keys with no following `=` sign.
    ///     name=John&isAdmin&age=21
    /// In the above example, `isAdmin` is a flag.
    public var omitFlags: Bool

    public init(omitEmptyValues: Bool = false, omitFlags: Bool = false) {
        self.parser = URLFormParser()
        self.omitFlags = omitFlags
        self.omitEmptyValues = omitEmptyValues
    }

    /// Decodes an instance of the supplied `Decodable` type from `Data`.
    ///     print(data) // "name=John&age=21"
    ///     let user = try URLFormDecoder().decode(User.self, from: data)
    ///     print(user) // User
    /// - parameters:
    ///     - decodable: Generic `Decodable` type (`D`) to decode.
    ///     - from: `Data` to decode a `D` from.
    /// - returns: An instance of the `Decodable` type (`D`).
    /// - throws: Any error that may occur while attempting to decode the specified type.
    public func decode<D>(_: D.Type, from data: Data) throws -> D where D: Decodable {
        let urlEncodedFormData = try parser.parse(
            percentEncoded: String(data: data, encoding: .utf8) ?? "",
            omitEmptyValues: self.omitEmptyValues,
            omitFlags: self.omitFlags)
        let decoder = URLFormDecoderCore(context: .init(.dict(urlEncodedFormData)), codingPath: [])
        return try D(from: decoder)
    }
}

/// Private `Decoder`. See `URLEncodedFormDecoder` for public decoder.
private final class URLFormDecoderCore: Decoder {
    init(context: URLFormDataContext, codingPath: [CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    let codingPath: [CodingKey]
    let context: URLFormDataContext
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key>
        where Key: CodingKey {
        .init(URLFormKeyedDecoder<Key>(context: self.context, codingPath: self.codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        URLFormUnkeyedDecoder(context: self.context, codingPath: self.codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        URLFormSingleValueDecoder(context: self.context, codingPath: self.codingPath)
    }
}

private final class URLFormSingleValueDecoder: SingleValueDecodingContainer {
    init(context: URLFormDataContext, codingPath: [CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    let context: URLFormDataContext
    var codingPath: [CodingKey]
    func decodeNil() -> Bool {
        self.context.data.get(at: self.codingPath) == nil
    }

    func decode<T>(_: T.Type) throws -> T where T: Decodable {
        guard let data = context.data.get(at: codingPath) else {
            throw DecodingError.valueNotFound(T.self, at: self.codingPath)
        }
        if let convertible = T.self as? URLFormDataConvertible.Type {
            return try convertible.convertFromURLEncodedFormData(data) as! T
        } else {
            let decoder = URLFormDecoderCore(context: context, codingPath: codingPath)
            return try T(from: decoder)
        }
    }
}

private final class URLFormKeyedDecoder<K>: KeyedDecodingContainerProtocol where K: CodingKey {
    init(context: URLFormDataContext, codingPath: [CodingKey]) {
        self.context = context
        self.codingPath = codingPath
    }

    typealias Key = K
    let context: URLFormDataContext
    var codingPath: [CodingKey]
    var allKeys: [K] {
        guard let dictionary = context.data.get(at: codingPath)?.dictionary else {
            return []
        }
        return dictionary.keys.compactMap { K(stringValue: $0) }
    }

    func contains(_ key: K) -> Bool {
        self.context.data.get(at: self.codingPath)?.dictionary?[key.stringValue] != nil
    }

    func decodeNil(forKey key: K) throws -> Bool {
        self.context.data.get(at: self.codingPath + [key]) == nil
    }

    func decode<T>(_: T.Type, forKey key: K) throws -> T where T: Decodable {
        guard let convertible = T.self as? URLFormDataConvertible.Type else {
            let decoder = URLFormDecoderCore(context: context, codingPath: codingPath + [key])
            return try T(from: decoder)
        }

        var data: URLFormData? {
            guard let _ = T.self as? String.Type else { return self.context.data.get(at: self.codingPath + [key]) }
            return self.context.data.get(at: self.codingPath + [key]) ?? ""
        }
        guard let data = data else { throw DecodingError.valueNotFound(T.self, at: self.codingPath + [key]) }

        return try convertible.convertFromURLEncodedFormData(data) as! T
    }

    func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey {
        .init(URLFormKeyedDecoder<NestedKey>(context: self.context, codingPath: self.codingPath + [key]))
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        URLFormUnkeyedDecoder(context: self.context, codingPath: self.codingPath + [key])
    }

    func superDecoder() throws -> Decoder {
        URLFormDecoderCore(context: self.context, codingPath: self.codingPath)
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        URLFormDecoderCore(context: self.context, codingPath: self.codingPath + [key])
    }
}

private final class URLFormUnkeyedDecoder: UnkeyedDecodingContainer {
    init(context: URLFormDataContext, codingPath: [CodingKey]) {
        self.context = context
        self.codingPath = codingPath
        self.currentIndex = 0
    }

    let context: URLFormDataContext
    var codingPath: [CodingKey]
    var currentIndex: Int
    var count: Int? {
        guard let array = context.data.get(at: codingPath)?.array else {
            return nil
        }
        return array.count
    }

    var isAtEnd: Bool {
        guard let count = count else {
            return true
        }
        return self.currentIndex >= count
    }

    var index: CodingKey {
        BasicKey(self.currentIndex)
    }

    func decodeNil() throws -> Bool {
        self.context.data.get(at: self.codingPath + [self.index]) == nil
    }

    func decode<T>(_: T.Type) throws -> T where T: Decodable {
        defer { currentIndex += 1 }
        if let convertible = T.self as? URLFormDataConvertible.Type {
            guard let data = context.data.get(at: codingPath + [index]) else {
                throw DecodingError.valueNotFound(T.self, at: self.codingPath + [self.index])
            }
            return try convertible.convertFromURLEncodedFormData(data) as! T
        } else {
            let decoder = URLFormDecoderCore(context: context, codingPath: codingPath + [index])
            return try T(from: decoder)
        }
    }

    func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey {
        .init(URLFormKeyedDecoder<NestedKey>(context: self.context, codingPath: self.codingPath + [self.index]))
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        URLFormUnkeyedDecoder(context: self.context, codingPath: self.codingPath + [self.index])
    }

    func superDecoder() throws -> Decoder {
        defer { currentIndex += 1 }
        return URLFormDecoderCore(context: self.context, codingPath: self.codingPath + [self.index])
    }
}

extension DecodingError {
    fileprivate static func typeMismatch(_ type: Any.Type, at path: [CodingKey]) -> DecodingError {
        let pathString = path.map { $0.stringValue }.joined(separator: ".")
        let context = DecodingError.Context(
            codingPath: path,
            debugDescription: "No \(type) was found at path \(pathString)")
        return Swift.DecodingError.typeMismatch(type, context)
    }

    fileprivate static func valueNotFound(_ type: Any.Type, at path: [CodingKey]) -> DecodingError {
        let pathString = path.map { $0.stringValue }.joined(separator: ".")
        let context = DecodingError.Context(
            codingPath: path,
            debugDescription: "No \(type) was found at path \(pathString)")
        return Swift.DecodingError.valueNotFound(type, context)
    }
}
