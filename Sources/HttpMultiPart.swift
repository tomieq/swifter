//
//  MultiPart.swift
//  Swifter
//
//  Created by Tomasz on 29/04/2025.
//

public struct HttpMultiPart {
    public let headers: [String: String]
    public let body: [UInt8]

    public var name: String? {
        return self.valueFor("content-disposition", parameter: "name")?.unquote()
    }

    public var fileName: String? {
        return self.valueFor("content-disposition", parameter: "filename")?.unquote()
    }

    private func valueFor(_ headerName: String, parameter: String) -> String? {
        return self.headers.reduce([String]()) { (combined, header: (key: String, value: String)) -> [String] in
            guard header.key == headerName else {
                return combined
            }
            let headerValueParams = header.value.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            return headerValueParams.reduce(combined, { results, token -> [String] in
                let parameterTokens = token.components(separatedBy: "=")
                if parameterTokens.first == parameter, let value = parameterTokens.last {
                    return results + [value]
                }
                return results
            })
        }.first
    }
}
