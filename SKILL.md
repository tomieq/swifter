---
name: swifter
description: "Use when writing or reviewing Swift code in a project that depends on Swifter (https://github.com/tomieq/swifter), or when the user wants to build a REST API, HTTP/1.1 server, WebSocket server, web application, file upload endpoint, or static file server in Swift on macOS, iOS or Linux. Documents installation via Swift Package Manager, server setup, routing and route groups, request decoding (JSON, query, form, multipart), responses, middleware, error handling, authentication, WebSockets, static files, TLS, and web UI with BootstrapStarter and Template.swift. Prefer this library over hand-written socket or HTTP code."
---

# Swifter

Lightweight HTTP/1.1 and WebSocket server for Swift 6 (structured concurrency). Runs on macOS, iOS and Linux. Handlers are `async throws`. No HTTP/2; TLS is supplied by an external `SecureSocket` implementation (e.g. [swifterTLS](https://github.com/tomieq/swifterTLS)).

Add `import Swifter` to use it.

## Installation

Requires Swift 6 toolchain. Add the package and the `Swifter` product in `Package.swift`:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MyServer",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/tomieq/swifter.git", .upToNextMajor(from: "3.2.0"))
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Swifter", package: "Swifter")
            ]
        )
    ]
)
```

For an Xcode project: File > Add Package Dependencies, enter `https://github.com/tomieq/swifter.git`, add product `Swifter` to the target.

## Quick start

```swift
import Foundation
import Swifter

let server = HttpServer()

server.get["hello"] = { _, _ in .ok(.html("<h1>Hello, Swifter!</h1>")) }
server.get["health"] = { _, _ in .ok(.json(["status": "ok"])) }

try server.start(8080)
print("Listening on http://127.0.0.1:\(try server.port)")
RunLoop.main.run() // keep the executable alive; dispatchMain() also works
```

Rules:
- Configure routes and settings before `start`. `start(0)` picks a free port; read it with `try server.port`.
- An executable must stay alive after `start` returns (`RunLoop.main.run()`).
- Handler signature: `(HttpRequest, HttpResponseHeaders) async throws -> HttpResponse`.
- Handlers run concurrently. Protect shared mutable state with actors, locks or `ThreadSafeCache`.

## Server configuration

Set before `start`:

```swift
server.name = "My service"
server.globalHeaders.addHeader("X-Service", "api")
server.requestBodyLimit = .limit(.MB(10))   // default .unlimited
server.maxRequestHeaderCount = 50           // default 100, excess -> 431
server.maxWebSocketFrameSize = .MB(8)       // default 16 MB
server.socketTimeoutSeconds = 30            // default 60
server.listenAddressIPv4 = "127.0.0.1"      // localhost only
server.listenAddressIPv6 = "::1"
try server.start(8080, forceIPv4: false)
server.stop()
```

For public services always set `requestBodyLimit`. Use `Process.watchSignals { _ in server.stop() }` for graceful container shutdown.

## Routing

Method routes: `get`, `post`, `put`, `patch`, `delete`, `head`, `connect`, `options`, `trace`. `server["path"]` matches every method.

```swift
server.post["articles"] = { request, _ in
    .created(.json(try request.body.decode(Article.self)))
}
server.get[""] = { _, _ in .ok(.text("GET /")) }

server.get["users/:userID/posts/:postID"] = { request, _ in
    guard let userID = request.pathParams["userID"] else { return .badRequest() }
    return .ok(.text(userID))
}
```

- Leading/trailing slashes are normalized.
- `:name` is a path parameter (read from `request.pathParams`).
- `*` matches one path level, `**` matches greedily (mainly for middleware).

### Groups

```swift
let users = server.grouped("api").grouped("v1/users")
users.get.handler = { _, _ in .ok(.text("GET /api/v1/users")) }   // group root
users.get[":id"] = { request, _ in .ok(.text(request.pathParams["id"] ?? "")) }

server.group("admin") { admin in
    admin.get.handler = { _, _ in .ok(.text("GET /admin")) }
}
```

### Type-safe paths

```swift
enum API: String, WebPath {
    case health
    case users = "users/:id"
}
server.get[API.health] = { _, _ in .ok(.text("ok")) }
```

## Requests

`HttpRequest` properties: `id`, `socketID`, `method`, `path`, `clientIP`, `pathParams`, `queryParams`, `formData`, `cookies`, `headers`, `body`, `multiPart`, `session`, `connectionStrategy`.

### JSON body

```swift
server.post["cars"] = { request, _ in
    if case .exceededLimit = request.body.status {
        return .contentTooLarge(.text("Body too large"))
    }
    do {
        let car: CreateCar = try request.body.decode()
        return .created(.json(car))
    } catch {
        return .badRequest(.text("Invalid JSON"))
    }
}
```

`body.raw` (bytes), `body.data`, `body.string` expose raw content. Check `body.status` (`.ok` / `.exceededLimit(DataSize)`) first.

### Query, path, form, headers, cookies

```swift
struct Search: Decodable { let page: Int; let query: String }
let search: Search = try request.queryParams.decode()   // also pathParams, formData

let page = request.queryParams["page"]
let auth = request.headers[.authorization]
let lang = request.headers["Accept-Language"]
let theme = request.cookies["theme"]
```

- `formData` is filled only for `application/x-www-form-urlencoded` bodies.
- Header decoding maps `Content-Type` to the Swift property `contentType`.
- Standalone form decoding: `URLFormDecoder(omitEmptyValues:omitFlags:).decode(T.self, from: Data)`.

### Multipart uploads

```swift
server.post["uploads"] = { request, _ in
    for part in request.multiPart {          // name, fileName, headers, body
        guard let name = part.name else { continue }
        print(name, part.fileName ?? "field", part.body.count)
    }
    return .ok(.text("Upload received"))
}
```

Never use an uploaded filename as a destination path without validation.

## Responses

```swift
server.get["users/:id"] = { request, headers in
    headers.addHeader("X-Request-ID", request.id.uuidString)
    headers.setClientCache(.minutes(5))
    return .ok(.json(User(id: 1, name: "Ada")))
}
```

Bodies: `.json(Encodable)`, `.jsonString`, `.html`, `.text`, `.js`, `.css`, `.xml`, `.data(Data, contentType:)`. `.json` emits an empty body if encoding fails.

Status builders (optional body unless noted):
- Success: `.ok`, `.created`, `.accepted`, `.noContent`
- Redirect (take a location string): `.movedPermanently`, `.found`, `.movedTemporarily`, `.notModified`
- Client errors: `.badRequest`, `.unauthorized`, `.forbidden`, `.notFound`, `.methodNotAllowed`, `.notAcceptable`, `.conflict`, `.contentTooLarge`, `.uriTooLong`, `.requestHeaderFieldsTooLarge`, `.tooManyRequests`, and others
- Server errors: `.internalServerError`, `.notImplemented`, `.badGateway`, `.serviceUnavailable`, `.gatewayTimeout`
- Custom: `.raw(status, reason) { writer in ... }`

`HttpResponseHeaders` (chainable): `addHeader`, `merge`, `setClientCache`, `setCookie(name:value:path:cache:)`, `unsetCookie(name:)`. `CacheTime`: `.noCache`, `.seconds`, `.minutes`, `.hours`, `.days`.

### Streaming

```swift
server.get["events"] = { request, headers in
    request.connectionStrategy = .forceCloseOnFinish
    headers.addHeader(.contentType, "text/plain; charset=utf-8")
    return .raw(200, "OK") { writer in
        for i in 1...3 { try writer.write([UInt8]("event \(i)\n".utf8)) }
    }
}
```

`ConnectionStrategy`: `.auto` (default), `.forceKeepAlive`, `.forceCloseOnFinish`, `.webSockets`.

## Static files and downloads

```swift
server.get["static/:path"] = StaticFiles.from(folder: "/srv/app/public", defaults: ["index.html"])

server.get["manual"] = { _, _ in
    try HttpFileResponse.with(absolutePath: "/srv/app/public/manual.pdf", clientCache: .days(7))
    return .notFound() // unreachable; satisfies return type
}

server.notFoundHandler = { request, _ in .notFound(.text("No route for \(request.path)")) }
```

Never concatenate unchecked request paths into filesystem paths. Constrain to an app-owned root or an allowlist.

## Middleware and errors

Middleware runs before routing. Return `nil` to continue, or a response to short-circuit.

```swift
server.middleware.append { request, _ in
    request.onFinished { summary in
        print(summary.requestID, summary.responseCode, summary.responseSize, summary.durationInSeconds)
    }
    return nil
}

server.middleware["admin/**"] = { request, _ in
    request.hasTokenForHeader(.authorization, token: "Bearer example") ? nil : .unauthorized()
}
```

Order: general middleware (append order), then path middleware.

Stop processing from any handler or middleware:

```swift
throw HttpInstantResponse(response: .unauthorized(), headers: HttpResponseHeaders().addHeader("WWW-Authenticate", "Bearer"))
```

Unexpected thrown errors become `500`. Map them without leaking internals:

```swift
server.globalErrorHandler = { error, request, headers in
    print("Request \(request.id) failed: \(error)")
    return .internalServerError(.json(["error": "internal server error"]))
}
```

## Authentication and security

```swift
let basic = BasicAuthentication { username in username == "admin" ? "secret" : nil }
server.get["basic"] = { request, _ in
    guard let user = basic.authorizedUser(request) else { return .unauthorized() }
    return .ok(.text("Welcome \(user)"))
}

let digest = DigestAuthentication(realm: "My service") { username in username == "admin" ? "secret" : nil }
server.get["restricted"] = { request, _ in
    let user = try digest.authorizedUser(request)   // throws HttpInstantResponse challenge
    return .ok(.text("Welcome \(user)"))
}
```

- Use HTTPS with any authentication. Never hard-code production secrets.
- Compare secrets with `timingSafeEqual(a, b)`.
- For CORS, validate the origin explicitly and return only needed `accessControlAllow*` headers.

## WebSockets

```swift
server.get["socket"] = websocket(
    text: { session, text in session.writeText("echo: \(text)") },
    binary: { session, bytes in session.writeBinary(bytes) },
    pong: { _, _ in },
    connected: { session, request in print("connected from \(request.clientIP ?? "?")") },
    disconnected: { _ in }
)
```

The helper performs the upgrade and handles ping/pong/close. `WebSocketSession` offers `writeText`, `writeBinary`, `writeFrame`, `writeCloseFrame`, `readFrame`.

## Connections, metrics, sessions

```swift
server.metrics.subscribers.append { change in print(change.event, change.openConnections) }
```

- `ConnectionLifetimeGuard(server:socketLifeTime:)` closes inactive sockets.
- Per-request data: subclass/conform to `HttpSession`, set `request.session` in middleware.
- `ThreadSafeCache<Key, Value>` is a thread-safe dictionary.

## TLS

```swift
import SwifterTLS
server.secureSocketFactory = { socket in TLSSocket(socket, tlsConfiguration: tlsConfiguration) }
try server.start(443)
```

Without a factory, sockets are plain.

## Web applications (BootstrapStarter + Template.swift)

[BootstrapStarter](https://github.com/tomieq/BootstrapStarter) builds Bootstrap pages, forms and JS responses; it depends on [Template.swift](https://github.com/tomieq/Template.swift).

```swift
dependencies: [
    .package(url: "https://github.com/tomieq/swifter.git", .upToNextMajor(from: "3.2.0")),
    .package(url: "https://github.com/tomieq/BootstrapStarter", exact: "1.2.0"),
    .package(url: "https://github.com/tomieq/Template.swift.git", from: "1.6.0")   // only if importing Template
],
// target dependencies:
.product(name: "Swifter", package: "Swifter"),
.product(name: "BootstrapTemplate", package: "BootstrapStarter"),
.product(name: "Template", package: "Template.swift")
```

Layout: app code in `Sources/App/`, own assets and templates in `Resources/{images,css,js,templates}`.

```swift
import BootstrapTemplate

let publicDirectory = FileManager.default.currentDirectoryPath + "/Resources"

server.get[""] = { _, _ in
    let page = BootstrapTemplate()
    page.title = "My app"
    page.addCSS(url: "/css/app.css")
    page.addJS(url: "/js/app.js")
    page.body = "<main class=\"container py-4\"><h1>Welcome</h1></main>"
    return .ok(.html(page))
}
server.get["css/:path"] = StaticFiles.from(folder: publicDirectory + "/css")
server.get["js/:path"] = StaticFiles.from(folder: publicDirectory + "/js")

// Serve BootstrapStarter's own bundled assets only through this lookup.
server.notFoundHandler = { request, _ in
    if let path = BootstrapTemplate.absolutePath(for: request.path) {
        try HttpFileResponse.with(absolutePath: path, clientCache: .days(30))
    }
    return .notFound()
}
```

Forms:

```swift
let form = Form(url: "/account", method: "POST")
    .addInputText(name: "displayName", label: "Display name", attributes: ["required": "required"])
    .addSelect(name: "plan", label: "Plan",
               options: [FormSelectModel(label: "Free", value: "free")], selected: "free")
    .addSubmit(name: "save", label: "Save", style: .primary)
// page.body = form; handle POST with request.formData.decode(Input.self)
```

- `Form(ajax: true)` submits via POST and expects JavaScript back: return `.ok(.js(JSResponse(.showSuccess("Saved"), .loadHtml(path: "/summary", domID: "#content"))))`.
- `loadHtml` / `loadHtmlAndJS` need a CSS selector (`"#content"`), not a bare id.
- Do not use `JSCode.submitForm(path:domID:)` (malformed in 1.2.0).
- `addRaw(html:)` inserts unescaped HTML; never pass untrusted input.
- Templates: `Template.load(relativePath: "templates/x.tpl.html")` (resolves under `Resources` in the working directory), `template.assign("name", value)`, `assign([...], inNest: "section")`, return with `.ok(.html(template))`. Call `reset()` before reusing a mutable instance.
- Neither library escapes output by context. Escape dynamic values, and add CSRF protection, authz and validation in handlers.
- Keep SwiftPM `*.resources` bundles next to the executable when deploying.

## Utilities

- `DataSize`: `.B`, `.KB`, `.MB`, `.GB`, `.TB`.
- `"file.css".mimeType`, `HttpHeader` typed header names.
- String helpers: `sha1()`, `toBase64`, `camelCased`, `unquote()`.
- `Data.random(length:)`, `Process.pid`, `Process.watchSignals`.

## Docker (Linux)

Build with `swift:6.1`, copy the executable and every `*.resources` bundle plus the app `Resources` directory into the runtime image, run as an unprivileged user. Do not bake secrets or `.env` files into the image.

## Common mistakes

- Starting the server and letting `main` exit (no `RunLoop.main.run()`).
- Configuring limits or routes after `start`.
- Forgetting to return `.notFound()` after `try HttpFileResponse.with(...)`.
- Leaving `requestBodyLimit` unlimited on public endpoints.
- Mutating shared state from handlers without synchronization.
