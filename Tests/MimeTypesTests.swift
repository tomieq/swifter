import Testing

@Suite struct MimeTypeTests {
    @Test func defaultValue() {
        #expect("file.null".mimeType == "application/octet-stream")
    }

    @Test func correctTypes() {
        #expect("file.html".mimeType == "text/html")
        #expect("file.css".mimeType == "text/css")
        #expect("file.mp4".mimeType == "video/mp4")
        #expect("file.pptx".mimeType == "application/vnd.openxmlformats-officedocument.presentationml.presentation")
        #expect("file.war".mimeType == "application/java-archive")
    }

    @Test func caseInsensitivity() {
        #expect("file.HTML".mimeType == "text/html")
        #expect("file.cSs".mimeType == "text/css")
        #expect("file.MP4".mimeType == "video/mp4")
        #expect("file.PPTX".mimeType == "application/vnd.openxmlformats-officedocument.presentationml.presentation")
        #expect("FILE.WAR".mimeType == "application/java-archive")
    }
}
