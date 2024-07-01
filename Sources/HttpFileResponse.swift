//
//  HttpFileResponse.swift
//
//
//  Created by Tomasz on 01/07/2024.
//

import Foundation

public enum HttpFileResponse {
    public static func with(absolutePath: String, responseHeaders headers: HttpResponseHeaders) -> HttpResponse? {
        guard FileManager.default.fileExists(atPath: absolutePath) else {
            return nil
        }
        guard let file = try? absolutePath.openForReading() else {
            return .notFound()
        }
        let mimeType = absolutePath.mimeType
        headers.addHeader("Content-Type", mimeType)

        if let attr = try? FileManager.default.attributesOfItem(atPath: absolutePath),
           let fileSize = attr[FileAttributeKey.size] as? UInt64 {
            headers.addHeader("Content-Length", String(fileSize))
        }

        return .raw(200, "OK", { writer in
            try writer.write(file)
            file.close()
        })
    }
}
