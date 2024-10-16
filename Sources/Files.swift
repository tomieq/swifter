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
            responseHeaders.addHeader("Content-Type", mimeType)
            if let attr = try? FileManager.default.attributesOfItem(atPath: path),
                let fileSize = attr[FileAttributeKey.size] as? UInt64 {
                responseHeaders.addHeader("Content-Length",  String(fileSize))
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
            responseHeaders.addHeader("Content-Type", mimeType)

            if let attr = try? FileManager.default.attributesOfItem(atPath: filePath),
                let fileSize = attr[FileAttributeKey.size] as? UInt64 {
                responseHeaders.addHeader("Content-Length", String(fileSize))
            }

            return .raw(200, "OK", { writer in
                try? writer.write(file)
                file.close()
            })
        }
        return .notFound()
    }
}

public func directoryBrowser(_ dir: String) -> HttpRequestHandler {
    return { request, responseHeaders in
        guard let value = request.pathParams.get("path") else {
            return HttpResponse.notFound()
        }
        let filePath = dir + String.pathSeparator + value
        do {
            guard try filePath.exists() else {
                return .notFound()
            }
            if try filePath.directory() {
                var files = try filePath.files()
                files.sort(by: {$0.lowercased() < $1.lowercased()})
                return scopes {
                    html {
                        body {
                            table(files) { file in
                                tr {
                                    td {
                                        a {
                                            href = request.path + "/" + file
                                            inner = file
                                        }
                                    }
                                }
                            }
                        }
                    }
                    }(request, responseHeaders)
            } else {
                guard let file = try? filePath.openForReading() else {
                    return .notFound()
                }
                return .raw(200, "OK", { writer in
                    try? writer.write(file)
                    file.close()
                })
            }
        } catch {
            return HttpResponse.internalServerError()
        }
    }
}
