//
//  StaticServer.swift
//  Swifter
//
//  Created by: tomieq on 18/05/2026
//

public enum StaticFiles {
    public static func from(
        folder folderPath: String,
        defaults: [String] = ["index.html", "default.html"]) -> HttpRequestHandler {
        return { request, responseHeaders in
            guard let fileRelativePath = request.pathParams["path"] else {
                return .notFound()
            }
            if fileRelativePath.isEmpty {
                for path in defaults {
                    if let file = try? (folderPath + String.pathSeparator + path).openForReading() {
                        return .rawAsync(200, "OK", { writer in
                            try? await writer.write(file)
                            file.close()
                        })
                    }
                }
            }
            let filePath = folderPath + String.pathSeparator + fileRelativePath
            print(filePath)
            try HttpFileResponse.with(absolutePath: filePath)
            return .notFound()
        }
    }
}
