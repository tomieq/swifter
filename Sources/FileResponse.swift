//
//  FileResponse.swift
//
//
//  Created by Tomasz on 01/07/2024.
//

import Foundation

public enum FileResponse {
    public static func with(absolutePath: String) throws {
        guard FileManager.default.fileExists(atPath: absolutePath) else {
            return
        }
        guard let file = try? absolutePath.openForReading() else {
            throw HttpInstantResponse(response: .notFound())
        }
        let headers = HttpResponseHeaders()
        let mimeType = absolutePath.mimeType
        headers.addHeader("Content-Type", mimeType)

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
