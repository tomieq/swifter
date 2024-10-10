![Platform](https://img.shields.io/badge/Platform-Linux.svg?style=flat)
![Swift](https://img.shields.io/badge/Swift-4.x,_5.0-4BC51D.svg?style=flat)
![Protocols](https://img.shields.io/badge/Protocols-HTTP%201.1%20&%20WebSockets-4BC51D.svg?style=flat)
[![CocoaPods](https://img.shields.io/cocoapods/v/Swifter.svg?style=flat)](https://cocoapods.org/pods/Swifter)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

### Why this fork?

I forked this repo to adjust the library to my needs. I refactored a little, removed linux incompatible classes and added some features I found useful (like cookie handling & setting).

### What is Swifter?

Tiny http server engine written in [Swift](https://developer.apple.com/swift/) programming language.

### Branches
`* 2.0.4` - latest release


### How to start?
```swift
let server = HttpServer()
server["hello"] = { request, responseHeaders in
    .ok(.html("html goes here"))  
}
server["code.js"] = { request, responseHeaders in
    .ok(.js("javascript goes here"))  
}
server["api"] = { request, responseHeaders in
    .ok(.json(<Encodeble object>))  
}
try server.start(8080)
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
server["/websocket-echo"] = websocket(text: { (session, text) in
    session.writeText(text)
}, binary: { (session, binary) in
    session.writeBinary(binary)
}, pong: { (_, _) in
    // Got a pong frame
}, connected: { _ in
    // New client connected
}, disconnected: { _ in
    // Client disconnected
})
try server.start()
```
### How to add routing with enum
```swift
enum RestApi: String, WebPath {
    case home = ""
    case contact
}
server.get[RestApi.home] = { _, _ in
    .ok(.text("welcome!"))
}
server.get[RestApi.contact] = { _, _ in
    .ok(.text("contact page"))
}
```
### How to compose routing
You can build routing with groups so they have common path prefixes:
```swift
// create a new routing groups with prefix `users`
let users = server.grouped("users")
// this route will be at URL: `/users`
users.get.handler  = { request, _ in
    .ok(.html("user list"))
}
users.post.handler  = { request, _ in
    .ok(.html("added user list"))
}
// this route will be at URL: `/users/avatars`
users.get["avatars"]  = { request, _ in
    .ok(.html("user avatars"))
}
// this route will be for specific user, e.g. `/users/876`
users.get[":id"]  = { request, _ in
    .ok(.html("user with id \(request.pathParams.get("id"))"))
}
```
You can also use this approach:
```swift
server.group("libraries") { libraries in
    // route from GET /libraries
    libraries.get.handler = { request, _ in
        .ok(.html("Welcome to libraries"))
    }
    libraries.post.handler = { request, _ in
        .ok(.html("Added new library"))
    }
    libraries.group("europe") { europe in
        // route from GET /libraries/europe/poland
        europe.get["poland"]  = { request, _ in
            .ok(.html("Library in Poland"))
        }
        // route from e.g GET /libraries/europe/cities/warsaw
        europe.get["cities/:city"]  = { request, _ in
            .ok(.html("Library in \(request.pathParams.get("city"))"))
        }
    }
}
```
In both approaches you can nest routes as deep as you like.
### How to make object from uploaded form data
```swift
server.post["uploadForm"] = { request, _ in
    struct User: Codable {
        let name: String
        let pin: Int
    }
    guard let user: User = try? request.formData.decode() else {
        return .badRequest(.text("Missing fields!"))
    }
    return .ok(.text("Uploaded for \(user.name)"))
}
```
### How to make object from query params
`GET /search?start=10limit=50&query=SELECT`
```swift
server.get["search"] = { request, _ in
    struct Search: Codable {
        let limit: Int
        let start: Int
        let query: String
    }
    guard let search: Search = try? request.queryParams.decode() else {
        return .badRequest(.text("Missing query params!"))
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
    guard let car: Car = try? request.body.decode() else {
        return .badRequest(.text("Invalid body"))
    }
    return .ok(.text("Car created \(car.make)"))
}
```
### How to make object from headers
Header field names are capitalized with first letter lowercased. That means that `Content-Type` becomes `conentType`:
```swift
server.get["resource"] = { request, _ in
    struct Header: Codable {
        let host: String
        let authorization: String
        let contentType: String
    }
    guard let headers: Header = try? request.headers.decode() else {
        return .badRequest(.text("Missing header fields!"))
    }
    return .ok(.text("Showing web page for \(headers.host)"))
}
```
### How to make object from path params
Header field names are capitalized with first letter lowercased. That means that `Content-Type` becomes `conentType`:
```swift
// /GET book/98/poker-face
server.get["book/:id/:title"] = { request, _ in
    struct Book: Codable {
        let id: Int
        let title: String
    }
    guard let book: Book = try? request.pathParams.decode() else {
        return .badRequest(.text("Invalid url"))
    }
    return .ok(.text("Title: \(book.title)"))
}
```
### How to return response instantly
You can implement some validation or authorization classes using `throw HttpInstantResponse`
```swift
server.post["restricted/user/changepassword"] = { request, _ in
    guard AccessValidator.canProcess(request) else {
        throw HttpInstantResponse(response: .unauthorized())
    }
    return .ok(.text("Password changed"))
}
```
### How to send custom Server header for every response
```swift
var server = HttpServer()
server.name = "Apache"
```
You can even set global headers that are send with every response until specific RequestHandler overrides it.
```swift
server.globalHeaders.addHeader("X-Docker-Instance", UUID().uuidString)
```
### How to stream data
```swift
server.get["/stream"] = { _, _ in
    return HttpResponse.raw(200, "OK", { writer in
        for index in 0...100 {
            try writer.write([UInt8]("[chunk \(index)]".utf8))
        }
    })
}
```
### How to serve static files
```swift
server.notFoundHandler = { [unowned self] request, responseHeaders in
    let absolutePath = ...
    try HttpFileResponse.with(absolutePath: absolutePath, clientCache: .days(7))
    print("File `\(absolutePath)` doesn't exist")
    return .notFound()
}
```
### How to add Basic Authentication?
You can easily add basic authentication using `BasicAuthentication` class. You need just to provide function that returns password for asked user:
```swift
server.get["basic"] = { request, _ in
    let basic = BasicAuthentication(credentialsProvider: { login in
        switch login {
        case "admin": "root"
        case "user": "12345"
        default: nil
        }
    })
    if let login = basic.authorizedUser(request) {
        return .ok(.text("Welcome \(login)"))
    }
    return .unauthorized(.text("Please authorize with basic"))
}
```
### How to add Digest Authentication?
You can add digest authentication using `DigestAuthentication` class. You need just to provide function that returns password for asked user:
```swift
server.get["restricted"] = { request, _ in
    let digest = DigestAuthentication(realm: "Swifter Digest", credentialsProvider: { login in
        switch login {
        case "admin": "root"
        case "user": "12345"
        default: nil
        }
    })
    let login = try digest.authorizedUser(request)
    return .ok(.text("Welcome \(login)"))
}
```
`DigestAuthentication` creates a proper challenge response, so it is a throwing function (throws proper `HttpInstantResponse`).
### How to add metric tracking
`HttpRequest` has `onFinished` closure that will be executed after request is finished
```swift
server.middleware.append( { request, header in
    print("Request \(request.id) \(request.method) \(request.path) from \(request.peerName ?? "")")
    request.onFinished = { id, code, duration in
        // finish tracking
        // id is unique UUID for this request
        // responseCode is the http code that was returned to client
        // duration is the time in seconds
        print("Request \(id) finished with \(code) in \(String(format: "%.3f", duration)) seconds")
    }
    return nil
})
```
### Socket metrics
If you are interested in watching amount of open sockets/connected clients, you can do it by 
```swift
server.metrics.onOpenConnectionsChanged = { number in
    print("amount of connections: \(number)")
}
/// or statically
print("amount of connections: \(server.metrics.openConnections)")
```
### Global error mapping
As your request handlers are allowed to throw Errors, you might register you error mapper:
```swift
server.globalErrorHandler = { error, request, headers in
    struct ErrorResponse: Codable {
        let code: Int
        let message: String
    }
    headers.addHeader("X-Retry-ID", UUID().uuidString)
    return .internalServerError(.json(ErrorResponse(code: 62, message: "Transaction aborted, please retry")))
}
```
If you want to hide all Errors, not show them in response, just:
```swift
server.globalErrorHandler = { _, _ in
    .internalServerError()
}
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
        .package(url: "https://github.com/tomieq/swifter.git", .upToNextMajor(from: "2.0.4"))
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
