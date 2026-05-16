//
//  HttpHandlers+Files.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public func shareFile(_ path: String) -> HttpRequestHandler {
    return { _, responseHeaders in
        if let file = try? path.openForReading() {
            let mimeType = path.mimeType
            responseHeaders.addHeader(.contentType, mimeType)
            if let attr = try? FileManager.default.attributesOfItem(atPath: path),
               let fileSize = attr[FileAttributeKey.size] as? UInt64 {
                responseHeaders.addHeader(.contentLength, String(fileSize))
            }
            return .raw(200, "OK", { writer in
                try? writer.write(file)
                file.close()
            })
        }
        return .notFound()
    }
}

public func shareFilesFromDirectory(_ directoryPath: String, defaults: [String] = ["index.html", "default.html"]) -> HttpRequestHandler {
    return { request, responseHeaders in
        guard let fileRelativePath = request.pathParams.get("path") else {
            return .notFound()
        }
        if fileRelativePath.isEmpty {
            for path in defaults {
                if let file = try? (directoryPath + String.pathSeparator + path).openForReading() {
                    return .raw(200, "OK", { writer in
                        try? writer.write(file)
                        file.close()
                    })
                }
            }
        }
        let filePath = directoryPath + String.pathSeparator + fileRelativePath

        if let file = try? filePath.openForReading() {
            let mimeType = fileRelativePath.mimeType
            responseHeaders.addHeader(.contentType, mimeType)

            if let attr = try? FileManager.default.attributesOfItem(atPath: filePath),
               let fileSize = attr[FileAttributeKey.size] as? UInt64 {
                responseHeaders.addHeader(.contentLength, String(fileSize))
            }

            return .raw(200, "OK", { writer in
                try? writer.write(file)
                file.close()
            })
        }
        return .notFound()
    }
}
