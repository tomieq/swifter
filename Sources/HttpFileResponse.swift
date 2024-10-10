//
//  HttpFileResponse.swift
//
//
//  Created by Tomasz on 01/07/2024.
//

import Foundation

public enum HttpFileResponse {
    public static func with(absolutePath: String, clientCache: CacheTime? = nil) throws {
        guard FileManager.default.fileExists(atPath: absolutePath) else {
            return
        }
        guard let file = try? absolutePath.openForReading() else {
            throw HttpInstantResponse(response: .notFound())
        }
        let headers = HttpResponseHeaders()
        headers.addHeader("Content-Type", absolutePath.mimeType)
        if let clientCache = clientCache {
            headers.setClientCache(clientCache)
        }

        if let attr = try? FileManager.default.attributesOfItem(atPath: absolutePath),
           let fileSize = attr[FileAttributeKey.size] as? UInt64 {
            headers.addHeader("Content-Length", String(fileSize))
        }
        throw HttpInstantResponse(response: .raw(200, "OK", { writer in
            try writer.write(file)
            file.close()
        }), headers: headers)
    }
}
