![Platform](https://img.shields.io/badge/Platform-Linux.svg?style=flat)
![Swift](https://img.shields.io/badge/Swift-4.x,_5.0-4BC51D.svg?style=flat)
![Protocols](https://img.shields.io/badge/Protocols-HTTP%201.1%20&%20WebSockets-4BC51D.svg?style=flat)
[![CocoaPods](https://img.shields.io/cocoapods/v/Swifter.svg?style=flat)](https://cocoapods.org/pods/Swifter)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

### Why this fork?

I forked this repo to adjust the library to my needs. I refactored a little, removed not-linux compatible classes and added some features I found useful (like cookie handling & setting). You can click `Compare` button on top of this page to see the difference.

### What is Swifter?

Tiny http server engine written in [Swift](https://developer.apple.com/swift/) programming language.

### Branches
`* 1.5.8` - latest release



### How to start?
```swift
let server = HttpServer()
server["/hello"] = { request, responseHeaders in
    .ok(.html("html goes here"))  
}
server["/js"] = { request, responseHeaders in
    .ok(.javaScript("javascript goes here"))  
}
server["/api"] = { request, responseHeaders in
    .ok(.json("json body"))  
}
server.start()
```

### How to keep the process running on Linux?
```swift
import Dispatch
dispatchMain()
```

### How to share files?
```swift
let server = HttpServer()
server["/desktop/:path"] = shareFilesFromDirectory("/Users/me/Desktop")
server.start()
```
### How to redirect?
```swift
let server = HttpServer()
server["/redirect"] = { request, _ in
  return .movedPermanently("http://www.google.com")
}
server.start()
```
### How to HTML ?
```swift
let server = HttpServer()
server["/my_html"] = scopes { 
  html {
    body {
      h1 { inner = "hello" }
    }
  }
}
server.start()
```
### How to WebSockets ?
```swift
let server = HttpServer()
server["/websocket-echo"] = websocket(text: { session, text in
  session.writeText(text)
}, binary: { session, binary in
  session.writeBinary(binary)
})
server.start()
```
### How to add metric tracking
`HttpRequest` has `onFinished` closure that will be executed after request is finished
```swift
server.middleware.append( { request, _ in
    // init tracking with request.id
    request.onFinished = { id, responseCode in
        // finish tracking; 
        // id is unique UUID for this request
        // responseCode is the http code that was returned to client
    }
    return nil
})
```
### How to add routing with enum
```swift
enum WebPath: String, Path {
    case home = ""
    case contact
}
server[WebPath.home] = { _, _ in
    .ok(.text("welcome!"))
}
server[WebPath.contact] = { _, _ in
    .ok(.text("contact page"))
}
```
### How to make object from uploaded form data
```swift
server.post["uploadForm"] = { request, _ in
    struct User: Codable {
        let name: String
        let pin: Int
    }
    guard let user: User = try? request.decodeFormData() else {
        return .badRequest(.text("Missing fields!"))
    }
    return .ok(.text("Uploaded for \(user.name)"))
}
```
### How to make object from query params
```swift
server.get["search"] = { request, _ in
    struct Search: Codable {
        let limit: Int
        let start: Int
        let query: String
    }
    guard let search: Search = try? request.decodeQueryParams() else {
        return .badRequest(.text("Missing params!"))
    }
    return .ok(.text("Search results for \(search.query)"))
}
```
### How to make object from body
```swift
server.post["create"] = { request, _ in
    struct Car: Codable {
        let weight: Int?
        let length: Int?
        let make: String
    }
    guard let car: Car = try? request.decodeBody() else {
        return .badRequest(.text("Invalid body"))
    }
    return .ok(.text("Car created \(car.make)"))
}
```
### How to make object from headers
Header field names are capitalized with first letter lowercased. That means that `Content-Type` becomes `conentType`:
```swift
server["headers"] = { request, _ in
    struct Header: Codable {
        let host: String
        let authorization: String
        let contentType: String
    }
    guard let headers: Header = try? request.decodeHeaders() else {
        return .badRequest(.text("Missing header fields!"))
    }
    return .ok(.text("Showing web page for \(headers.host)"))
}
```
### CocoaPods? Yes.
```ruby
use_frameworks!

pod 'Swifter', '~> 1.5.0'
```

### Carthage? Also yes.
```
github "tomieq/swifter" ~> 1.5.0
```

### Swift Package Manager.
```swift
import PackageDescription

let package = Package(
    name: "MyServer",
    dependencies: [
        .package(url: "https://github.com/tomieq/swifter.git", .upToNextMajor(from: "1.5.0"))
    ]
)
```
in the target:
```swift
    targets: [
        .executableTarget(
            name: "AppName",
            dependencies: [
                .product(name: "Swifter", package: "Swifter")
            ])
    ]
```
### Docker.
```
docker run -d -p 9080:9080 -v `pwd`:/Swifter -w /Swifter --name Swifter swift bash -c "swift run"
```

