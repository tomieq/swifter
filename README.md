# Swifter

![Platform](https://img.shields.io/badge/Platform-iOS%2C%20macOS%2C%20Linux-blue.svg?style=flat)
![Swift](https://img.shields.io/badge/Swift-6.0+-4BC51D.svg?style=flat)
![Protocols](https://img.shields.io/badge/Protocols-HTTP%2F1.1%20%26%20WebSockets-4BC51D.svg?style=flat)

Swifter is a lightweight HTTP/1.1 and WebSocket server for Swift. This fork uses Swift 6 structured concurrency and runs on macOS, iOS, and Linux. It provides routing, request decoding, streaming, multipart uploads, middleware, authentication, metrics, and an optional TLS socket hook.

> **Protocol scope:** Swifter serves HTTP/1.1 and RFC 6455 WebSockets. It does not implement HTTP/2. TLS is supplied by an external `SecureSocket` implementation, such as [swifterTLS](https://github.com/tomieq/swifterTLS).

## Contents

- [Install](#install)
- [Quick start](#quick-start)
- [Server lifecycle and configuration](#server-lifecycle-and-configuration)
- [Routing](#routing)
- [Requests and decoding](#requests-and-decoding)
- [Responses](#responses)
- [Static files and downloads](#static-files-and-downloads)
- [Middleware and errors](#middleware-and-errors)
- [Authentication and security](#authentication-and-security)
- [WebSockets](#websockets)
- [Connections, metrics, and sessions](#connections-metrics-and-sessions)
- [TLS](#tls)
- [Utilities](#utilities)
- [Public API reference](#public-api-reference)
- [Web applications with BootstrapStarter and Template.swift](#web-applications-with-bootstrapstarter-and-templateswift)
- [Docker deployment](#docker-deployment)

## Install

Swifter requires Swift 6. Add it to an executable package:

```swift
// Package.swift
import PackageDescription

let package = Package(
    name: "MyServer",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    dependencies: [
        .package(
            url: "https://github.com/tomieq/swifter.git",
            .upToNextMajor(from: "3.2.0")
        )
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

Import `Swifter` where the server is configured.

## Quick start

Handlers are `async throws`, so they can use Swift concurrency directly. Configure routes before starting the server.

```swift
import Foundation
import Swifter

let server = HttpServer()

server.get["hello"] = { _, _ in
    .ok(.html("<h1>Hello, Swifter!</h1>"))
}

server.get["health"] = { _, _ in
    .ok(.json(["status": "ok"]))
}

try server.start(8080)
print("Listening on http://127.0.0.1:\(try server.port)")

// An executable must remain alive after start() returns.
RunLoop.main.run()
```

On Linux, `dispatchMain()` is an equally suitable process-lifetime call:

```swift
import Dispatch
dispatchMain()
```
or
```
RunLoop.main.run()
```

## Server lifecycle and configuration

`HttpServer` inherits listener settings from `HttpServerIO`. Set them before `start`.

```swift
let server = HttpServer()
server.name = "My service"                         // Server response header
server.globalHeaders.addHeader("X-Service", "api")
server.requestBodyLimit = .limit(.MB(10))
server.maxRequestHeaderCount = 50
server.maxWebSocketFrameSize = .MB(8)
server.socketTimeoutSeconds = 30
server.listenAddressIPv4 = "127.0.0.1"             // optional: localhost only
server.listenAddressIPv6 = "::1"

try server.start(8080, forceIPv4: false)
```

`start(_:, forceIPv4:, priority:)` throws if a listener cannot be created. Pass port `0` to let the operating system choose a free port, then read `try server.port`. `state` reports `.starting`, `.running`, `.stopping`, or `.stopped`; `operating` is `true` only while running. `stop()` stops accepting work and closes tracked sockets. Use `close(socketID:)` only when application policy needs to end a specific connection. `isIPv4()` reports the protocol used by the active server socket.

### Production limits

Public services should set conservative limits:

- `requestBodyLimit`: `.unlimited` by default; use `.limit(DataSize)` for public endpoints.
- `maxRequestHeaderCount`: defaults to `100`; excessive headers are rejected with `431`.
- `socketTimeoutSeconds`: defaults to `60` and is applied as receive/send socket timeouts.
- `maxWebSocketFrameSize`: defaults to `16 MB`; set it according to the largest supported client message.

## Routing

Swifter routes by HTTP method. Available method routes are `get`, `post`, `put`, `patch`, `delete`, `head`, `connect`, `options`, and `trace`.

```swift
server.get["articles"] = { _, _ in .ok(.text("list")) }
server.post["articles"] = { request, _ in
    .created(.json(try request.body.decode(Article.self)))
}

// A route registered on the server itself accepts every HTTP method.
server["status"] = { request, _ in
    .ok(.text("received \(request.method.rawValue)"))
}

// Register a method-specific root route with an empty path.
server.get[""] = { _, _ in .ok(.text("GET /")) }
```

Leading and trailing slashes are normalized. Route placeholders begin with `:` and are decoded into `request.pathParams`.

```swift
server.get["users/:userID/posts/:postID"] = { request, _ in
    guard let userID = request.pathParams["userID"],
          let postID = request.pathParams["postID"] else {
        return .badRequest()
    }
    return .ok(.text("User \(userID), post \(postID)"))
}
```

Use `*` for one path level and `**` for a greedy path match where applicable, particularly for middleware. Review `server.routes` at startup to inspect registered routes.

### Route groups

Groups make shared prefixes explicit and can be nested.

```swift
let api = server.grouped("api")
let users = api.grouped("v1/users")

users.get.handler = { _, _ in
    .ok(.text("GET /api/v1/users"))
}
users.get[":id"] = { request, _ in
    .ok(.text("GET /api/v1/users/\(request.pathParams["id"] ?? "")"))
}

server.group("admin") { admin in
    admin.get.handler = { _, _ in .ok(.text("GET /admin")) }
    admin.group("reports") { reports in
        reports.get["daily"] = { _, _ in .ok(.text("report")) }
    }
}
```

`GroupedRoute` exposes the same method routes and supports further `grouped(_:)` and `group(_:_:)` calls. A grouped method route has `handler` for its group's root and a path subscript for children.

### Type-safe paths

Conform a `RawRepresentable<String>` route enum to `WebPath`.

```swift
enum API: String, WebPath {
    case health
    case users = "users/:id"
}

server.get[API.health] = { _, _ in .ok(.text("ok")) }
server.get[API.users] = { request, _ in
    .ok(.text(request.pathParams["id"] ?? ""))
}
```

`WebPath` values are accepted by server routes, method routes, groups, and middleware.

## Requests and decoding

Every handler receives `HttpRequest` and a mutable `HttpResponseHeaders` object.

| Property | Purpose |
| --- | --- |
| `id`, `socketID` | Request and connection identifiers. |
| `method`, `path`, `clientIP` | Request method, normalized path, and peer address when available. |
| `pathParams`, `queryParams`, `formData`, `cookies` | URL, form, and cookie key/value collections. |
| `headers` | Case-insensitive header collection. |
| `body` | JSON-decodable request bytes and body-limit status. |
| `multiPart` | Lazily parsed multipart fields and uploads. |
| `session` | Application-defined per-request storage. |
| `connectionStrategy` | Overrides automatic keep-alive handling. |

### JSON bodies

`HttpRequestBody.decode(_:)` uses enables creating objects from HTTP body.

```swift
struct CreateCar: Codable {
    let make: String
    let weight: Int?
}

server.post["cars"] = { request, _ in
    if case .exceededLimit = request.body.status {
        return .contentTooLarge(.text("Request body is too large"))
    }

    do {
        let car: CreateCar = try request.body.decode()
        return .created(.json(car))
    } catch {
        return .badRequest(.text("Invalid JSON"))
    }
}
```

`body.raw`, `body.data`, and `body.string` expose the same content as bytes, `Data`, and optional UTF-8 text. Check `body.status` before using it: the cases are `.ok` and `.exceededLimit(DataSize)`.

### Query, path, headers, cookies, and forms

`HttpRequestParams` supports `request.queryParams["page"]`, `get(_:)`, `list`, `dict`, and `decode(_:)`. Decode structured query or path parameters with a `Decodable` model.

```swift
struct Search: Decodable {
    let page: Int
    let query: String
}

server.get["search"] = { request, _ in
    do {
        let search: Search = try request.queryParams.decode()
        return .ok(.text("\(search.query), page \(search.page)"))
    } catch {
        return .badRequest(.text("Expected page and query"))
    }
}
```

For headers, use typed names when available or a string. Header parameter decoding maps a hyphenated name such as `Content-Type` to the Swift property `contentType`.

```swift
if let authorization = request.headers[.authorization] {
    // Validate the credential.
}
let language = request.headers["Accept-Language"]
let theme = request.cookies["theme"]
```

`formData` is populated only for `application/x-www-form-urlencoded` requests. It has the same direct-access and `Decodable` APIs as query parameters.

For standalone URL-encoded input, use `URLFormDecoder`. It supports nested data and arrays encoded by the URL form parser.

```swift
let decoder = URLFormDecoder(omitEmptyValues: true, omitFlags: true)
let filter = try decoder.decode(Search.self, from: Data("page=1&query=swift".utf8))
```

Set `omitEmptyValues` to ignore `field=` and `omitFlags` to ignore a key without `=`. Custom decoded leaf values can conform to `URLFormDataConvertible`; lower-level integrations can use `LosslessDataConvertible`, `NestedData`, `BasicKey`, `BasicKeyRepresentable`, `URLFormData`, `URLFormDataContext`, `URLFormParser`, and `URLFormError`.

### Multipart uploads

`request.multiPart` lazily parses `multipart/form-data`. Each `HttpMultiPart` has `headers`, raw `body` bytes, plus optional `name` and `fileName` derived from `Content-Disposition`.

```swift
server.post["uploads"] = { request, _ in
    if case .exceededLimit = request.body.status { return .contentTooLarge() }

    for part in request.multiPart {
        // Each HttpMultiPart has headers, body, name and fileName properties.
        guard let name = part.name else { continue }
        print("\(name): \(part.fileName ?? "field"), \(part.body.count) bytes")
        // Validate type and size, then write only to an application-controlled path.
    }
    return .ok(.text("Upload received"))
}
```

Never use an uploaded filename as a destination path without validation. Store uploads outside publicly served directories unless they are intentionally public.

## Responses

Return an `HttpResponse` from a handler. `HttpResponseBody` selects the content type and accepts any `CustomStringConvertible` for text formats.

```swift
struct User: Encodable { let id: Int; let name: String }

server.get["users/:id"] = { request, headers in
    headers.addHeader("X-Request-ID", request.id.uuidString)
    headers.setClientCache(.minutes(5))
    return .ok(.json(User(id: 1, name: "Ada")))
}
```

Body constructors are `.json(Encodable)`, `.jsonString(CustomStringConvertible)`, `.html`, `.text`, `.js`, `.css`, `.xml`, and `.data(Data, contentType:)`. `.json` uses `JSONEncoder`; if encoding fails it emits an empty body, so validate models in tests.

### Status and redirects

The response enum covers these status builders:

| Category | Builders |
| --- | --- |
| Informational | `.switchProtocols`, `.processing` |
| Success | `.ok`, `.created`, `.accepted`, `.noContent` |
| Redirect | `.movedPermanently`, `.found`, `.movedTemporarily`, `.notModified` |
| Client errors | `.badRequest`, `.unauthorized`, `.forbidden`, `.notFound`, `.methodNotAllowed`, `.notAcceptable`, `.conflict`, `.contentTooLarge`, `.uriTooLong`, `.requestHeaderFieldsTooLarge`, `.iAmTeapot`, `.locked`, `.tooEarly`, `.tooManyRequests` |
| Server errors | `.internalServerError`, `.notImplemented`, `.badGateway`, `.serviceUnavailable`, `.gatewayTimeout` |
| Custom | `.raw(status, reason, writer)` |

Most error and success builders accept an optional body. Redirect builders accept a location string. `statusCode`, `reasonPhrase`, and `responseHeaders` expose a response's generated metadata.

### Headers, cookies, and caching

The response-headers object passed to a handler is merged with generated headers. `HttpResponseHeaders` supports `addHeader`, `merge`, `setClientCache`, `setCookie`, and `unsetCookie`; all return the same object for chaining.

```swift
server.get["login"] = { _, headers in
    headers
        .setCookie(name: "session", value: "signed-token", path: "/", cache: .hours(2))
        .unsetCookie(name: "old_session")
        .setClientCache(.noCache) // Cache-Control: max-age=2592000
        .addHeader("X-Content-Type-Options", "nosniff")
    return .ok(.text("Signed in"))
}
```

`CacheTime` provides `.noCache`, `.seconds`, `.minutes`, `.hours`, and `.days`. `HttpHeader` is the typed catalog of common request and response header names; use a raw string for headers outside that catalog.

### Streaming

Use `.raw` to write a response body progressively. A `HttpResponseBodyWriter` accepts `write([UInt8])` and `write(Data)`.

```swift
server.get["events"] = { request, headers in
    request.connectionStrategy = .forceCloseOnFinish  // close after response
    headers.addHeader(.contentType, "text/plain; charset=utf-8")
    return .raw(200, "OK") { writer in
        for index in 1...3 {
            try writer.write([UInt8]("event \(index)\n".utf8))
        }
    }
}
```

Set `request.connectionStrategy = .forceCloseOnFinish` for responses that should not keep the connection open. The other cases are `.auto` (the default), `.forceKeepAlive`, and `.webSockets`.

## Static files and downloads

For a known static directory, capture the requested tail and use `StaticFiles.from(folder:defaults:)`.

```swift
server.get["static/:path"] = StaticFiles.from(
    folder: "/srv/my-app/public",
    defaults: ["index.html"]
)
```

For a single application-selected file, call `HttpFileResponse.with(absolutePath:clientCache:)`. It throws `HttpInstantResponse`, which ends the handler with the correct file response.

```swift
server.get["manual"] = { _, _ in
    try HttpFileResponse.with(
        absolutePath: "/srv/my-app/public/manual.pdf",
        clientCache: .days(7)
    )
    return .notFound() // Unreachable; satisfies the handler's return type.
}
```

Do not concatenate unchecked request paths into a filesystem path. Resolve, normalize, and constrain a path to an application-owned root, or use a fixed allowlist. `StaticFiles` is appropriate for trusted application assets, not user-uploaded or private data.

Set `notFoundHandler` to add a fallback, for example an application asset resolver followed by a custom 404.

```swift
server.notFoundHandler = { request, _ in
    .notFound(.text("No route for \(request.path)"))
}
```

## Middleware and errors

Middleware runs before routing. It receives the request and response headers, returns `nil` to continue, or returns a response to short-circuit the request. It may throw.

```swift
server.middleware.append { request, header in
    print("Request \(request.id) \(request.method) \(request.path) from \(request.clientIP ?? "")")
    request.onFinished { summary in
        // finish tracking
        // id is unique UUID for this request
        // socketID is unique UUID for socket handling request
        // responseCode is the http code that was returned to client
        // responseSize is expressed in DataSize
        // durationInSeconds is the time in seconds
        print("Request \(summary.requestID) finished with \(summary.responseCode) [\(summary.responseSize)] in \(String(format: "%.3f", summary.durationInSeconds)) seconds")
    }
    return nil
}

server.middleware["admin/**"] = { request, _ in
    guard request.hasTokenForHeader(.authorization, token: "Bearer example") else {
        return .unauthorized(.text("Authentication required"))
    }
    return nil
}
```

General middleware runs in append order, followed by matching path middleware. Use `*` for a single path level and `**` for a greedy match. Typed `WebPath` middleware is also supported.

Throw `HttpInstantResponse` from a handler or middleware to stop processing with a deliberate response and optional headers.

```swift
guard isAllowed else {
    let headers = HttpResponseHeaders().addHeader("WWW-Authenticate", "Bearer")
    throw HttpInstantResponse(response: .unauthorized(), headers: headers)
}
```

Unexpected thrown errors become `500` responses by default. Provide `globalErrorHandler` to log and map them without exposing internal details.

```swift
server.globalErrorHandler = { error, request, headers in
    print("Request \(request.id) failed: \(error)")
    headers.addHeader("X-Request-ID", request.id.uuidString)
    return .internalServerError(.json(["error": "internal server error"]))
}
```

`HttpRequestHandler`, `HttpMiddlewareHandler`, and `HttpGlobalErrorHandler` are the public handler type aliases. `HttpRouter` can also be used directly through `register`, `route`, and `routes` when building an advanced custom server.

## Authentication and security

### Basic authentication

`BasicAuthentication` asks its credentials provider for the password corresponding to a supplied username.

```swift
let basic = BasicAuthentication { username in
    username == "admin" ? "correct-horse-battery-staple" : nil
}

server.get["basic"] = { request, _ in
    guard let username = basic.authorizedUser(request) else {
        return .unauthorized(.text("Credentials required"))
    }
    return .ok(.text("Welcome \(username)"))
}
```

### Digest authentication

`DigestAuthentication.authorizedUser(_:)` throws an `HttpInstantResponse` challenge when credentials are absent or invalid.

```swift
let digest = DigestAuthentication(realm: "My service") { username in
    username == "admin" ? "password-from-secure-store" : nil
}

server.get["restricted"] = { request, _ in
    let username = try digest.authorizedUser(request)
    return .ok(.text("Welcome \(username)"))
}
```

Use HTTPS for all authentication mechanisms. Do not hard-code production passwords. `timingSafeEqual` compares `String` or `[UInt8]` secrets without a timing-dependent early exit.

```swift
guard timingSafeEqual(providedToken, expectedToken) else {
    return .unauthorized()
}
```

For CORS, explicitly validate allowed origins and return only the headers required by the browser client.

```swift
server.options["api/**"] = { request, headers in
    guard request.headers[.origin] == "https://app.example.com" else {
        return .forbidden()
    }
    headers.addHeader(.accessControlAllowOrigin, "https://app.example.com")
    headers.addHeader(.accessControlAllowMethods, "GET, POST, OPTIONS")
    headers.addHeader(.accessControlAllowHeaders, "Content-Type, Authorization")
    return .noContent
}
```

## WebSockets

Register a `websocket` handler on a GET route. The helper performs the upgrade, handles ping/pong and close frames, and invokes supplied closures.

```swift
server.get["socket"] = websocket(
    text: { session, text in
        session.writeText("echo: \(text)")
    },
    binary: { session, bytes in
        session.writeBinary(bytes)
    },
    pong: { _, _ in
        // A client pong was received.
    },
    connected: { session, request in
        print("WebSocket \(session.hashValue) from \(request.clientIP ?? "unknown")")
    },
    disconnected: { _ in
        print("WebSocket closed")
    }
)
```

`WebSocketSession` exposes its `socket`, immutable `maxFrameSize`, `writeText`, `writeBinary`, `writeFrame`, `writeCloseFrame`, and `readFrame`. `writeFrame` accepts an `OpCode` (`.continue`, `.text`, `.binary`, `.close`, `.ping`, or `.pong`) and an optional final-frame flag. `readFrame()` returns a `Frame` and can throw `WsError` or `Control.close`.

The server copies `maxWebSocketFrameSize` into `request.serverMaxWebSocketFrameSize` for the upgrade helper. Configure the server limit before start; protect application memory by keeping it low enough for the expected payload.

## Connections, metrics, and sessions

`server.metrics.openConnections` reports the current count. Append `ConnectionChangeHandler` callbacks to observe `.connected`, `.traffic`, `.webSocketSessionStarted`, and `.disconnected` events.

```swift
server.metrics.subscribers.append { change in
    print("\(change.event): \(change.openConnections) open sockets")
}
```

Metrics callbacks add work on connection events. Measure their impact before enabling high-volume logging in production. `ConnectionLifetimeGuard(server:socketLifeTime:)` observes metrics and closes inactive connections after the chosen `TimeInterval`.

Use `onFinished(_:)` for per-request accounting. It receives an `HttpRequestSummary` containing request/socket identifiers, response code, response `DataSize`, and duration in seconds.

```swift
server.middleware.append { request, _ in
    request.onFinished { summary in
        print("\(summary.responseCode) \(summary.responseSize) in \(summary.durationInSeconds)s")
    }
    return nil
}
```

For request-scoped application data, define an `HttpSession` type and store it in `request.session`. Do not share a mutable session instance across concurrent requests unless the type supplies its own synchronization.

```swift
final class CurrentUser: HttpSession {
    let id: String
    init(id: String) { self.id = id }
}

server.middleware.append { request, _ in
    request.session = CurrentUser(id: "42")
    return nil
}
```

`ThreadSafeCache<Key, Value>` is a dispatch-barrier-protected dictionary for safely shared cache values. It provides `init()`, `all`, a normal key subscript, and a default-value subscript.

## TLS

Swifter delegates TLS to `secureSocketFactory`. Its default factory passes through plain sockets; configure a TLS implementation before starting.

```swift
import Swifter
import SwifterTLS

let server = HttpServer()
server.secureSocketFactory = { socket in
    TLSSocket(socket, tlsConfiguration: tlsConfiguration)
}
try server.start(443)
```

The public `SecureSocket` protocol defines the socket operations used by the HTTP parser. Implement it only when integrating a custom transport or TLS provider. The lower-level `Socket`, `SocketError`, and `Errno` APIs expose listening, acceptance, reads, writes, timeouts, and file transfer for advanced integrations.

## Utilities

- `DataSize` represents byte counts as `.B`, `.KB`, `.MB`, `.GB`, or `.TB`, has initializers from numeric counts and `Data`, and exposes `count`, `description`, and `Comparable` conformance.
- `HttpHeader` is the common typed header-name enum; `description` and `rawValue` return its wire spelling.
- `MimeType` adds `mimeType` to file-name strings, for example `"app.css".mimeType`.
- String extensions provide `sha1() -> [UInt8]`, `sha1() -> String`, `String.toBase64(_:)`, `camelCased`, `lowercasingFirst`, `uppercasingFirst`, `unquote()`, and `asWhitespace()`.
- File-path string extensions provide `openNewForWriting`, `openForReading`, `openForWritingAndReading`, `exists`, `directory`, `files`, and `String.pathSeparator`.
- `Data.random(length:)` creates random data; `UInt64.readableSizeWithUnit` formats a byte count.
- `Process.pid`, `Process.tid`, and `Process.watchSignals(_:)` expose process information and signal observation. Use `watchSignals` to stop cleanly on container shutdown.

```swift
Process.watchSignals { signal in
    print("Stopping after signal \(signal)")
    server.stop()
}
```

## Public API reference

This section is an index of the supported public surface. Prefer the higher-level sections above for examples.

| Area | Public API |
| --- | --- |
| Server | `HttpServer`, `HttpServerIO`, `HttpServerIODelegate`, `HttpServerIO.HttpServerIOState`, `RequestBodyLimit`, `HttpServer.MethodRoute`, `HttpServer.GroupedRoute`, `HttpServer.GroupedMethodRoute` |
| Routing | `HttpRequestHandler`, `HttpMiddlewareHandler`, `HttpGlobalErrorHandler`, `HttpRouter`, `HttpMethod`, `WebPath` |
| Request | `HttpRequest`, `HttpRequestBody`, `HttpRequestBodyStatus`, `HttpRequestParams`, `HttpRequestHeaderParams`, `HttpMultiPart`, `HttpRequestSummary`, `ConnectionStrategy`, `HttpSession` |
| Response | `HttpResponse`, `HttpResponseBody`, `HttpResponseBodyWriter`, `HttpResponseHeaders`, `HttpFileResponse`, `HttpCode`, `CacheTime`, `SerializationError` |
| Middleware/errors | `Middleware`, `HttpInstantResponse` |
| WebSockets | `websocket`, `WebSocketSession`, `WebSocketSession.Frame`, `WebSocketSession.OpCode`, `WebSocketSession.WsError`, `WebSocketSession.Control` |
| Connections | `ConnectionMetrics`, `ConnectionChange`, `ConnectionEvent`, `ConnectionChangeHandler`, `ConnectionLifetimeGuard`, `ThreadSafeCache` |
| Authentication | `BasicAuthentication`, `DigestAuthentication`, `timingSafeEqual` |
| Forms | `URLFormDecoder`, `URLFormError`, `URLFormDataConvertible`, `LosslessDataConvertible`, `NestedData`, `URLFormData`, `URLFormDataContext`, `URLFormParser`, `BasicKey`, `BasicKeyRepresentable`, `Byte`, `Bytes`, pointer aliases |
| Sockets | `Socket`, `SecureSocket`, `SocketError`, `Errno` |
| Utilities | `DataSize`, `HttpHeader`, `SHA1`, `MimeType`, `Process`, `Data.random` and the public String/UInt64 extensions |

Most server classes are marked `@unchecked Sendable` because they wrap operating-system sockets and synchronization primitives. Handlers may execute concurrently. Treat application-owned mutable state as concurrent state: use actors, locks, immutable values, or safe containers such as `ThreadSafeCache`.

## Web applications with BootstrapStarter and Template.swift

[BootstrapStarter](https://github.com/tomieq/BootstrapStarter) `1.2.0` is the recommended UI layer for Swifter web services. It builds full Bootstrap pages, forms, and JavaScript responses. It uses [Template.swift](https://github.com/tomieq/Template.swift) internally, so applications get Bootstrap page templates and can also use `Template` directly for application-specific fragments.

### Add the packages

Declare Swifter and BootstrapStarter in the executable package. BootstrapStarter brings Template.swift transitively; add Template.swift explicitly only when the app imports `Template` for custom templates.

```swift
// Package.swift
import PackageDescription

let package = Package(
    name: "MyWebApp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/tomieq/swifter.git", .upToNextMajor(from: "3.2.0")),
        .package(url: "https://github.com/tomieq/BootstrapStarter", exact: "1.2.0"),
        .package(url: "https://github.com/tomieq/Template.swift.git", from: "1.6.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Swifter", package: "Swifter"),
                .product(name: "BootstrapTemplate", package: "BootstrapStarter"),
                .product(name: "Template", package: "Template.swift")
            ]
        )
    ]
)
```

Use `import BootstrapTemplate` for `BootstrapTemplate`, `Form`, `JSCode`, `JSResponse`, `FormRadioModel`, `FormSelectModel`, and `ButtonStyle`. Use `import Template` only for application templates.

### Recommended application layout

Keep executable code, user-visible assets, and source templates separate:

```text
Sources/App/
  main.swift
  Routes/
  Views/
Resources/
  images/
    logo.svg
    favicon.png
  css/
    app.css
  js/
    app.js
  templates/
    account.tpl.html
```

Place custom images, CSS, JavaScript, downloads, and hand-authored HTML in the application's `Resources` directory. They are your assets, not BootstrapStarter assets. In development, load custom Template.swift templates using an explicit application resource path. In a container, copy the application `Resources` directory to the runtime working directory, as shown below.

BootstrapStarter owns its bundled CSS and JavaScript. Never copy or modify its internal resource paths. Serve a request only when `BootstrapTemplate.absolutePath(for:)` returns a path; this keeps the asset fallback constrained to the package bundle.

### Complete page and asset setup

The following application returns a Bootstrap page, serves its bundled assets safely, and serves custom assets from an explicit app-owned directory.

```swift
import Foundation
import Swifter
import BootstrapTemplate

let server = HttpServer()
let publicDirectory = FileManager.default.currentDirectoryPath + "/Resources"

server.get[""] = { _, _ in
    let page = BootstrapTemplate()
    page.title = "Swifter web app"
    page.addMeta(name: "description", value: "A Swifter and BootstrapStarter application")
    page.addFavicon(url: "/images/favicon.png", type: "image/png")
    page.addCSS(url: "/css/app.css")
    page.addJS(url: "/js/app.js")
    page.body = """
    <main class="container py-4">
      <img src="/images/logo.svg" alt="Example logo" height="48">
      <h1 class="mt-3">Welcome</h1>
      <div id="content"></div>
    </main>
    """
    return .ok(.html(page))
}

server.get["images/:path"] = StaticFiles.from(folder: publicDirectory + "/images")
server.get["css/:path"] = StaticFiles.from(folder: publicDirectory + "/css")
server.get["js/:path"] = StaticFiles.from(folder: publicDirectory + "/js")

server.notFoundHandler = { request, _ in
    // BootstrapStarter maps only its known package resources.
    if let path = BootstrapTemplate.absolutePath(for: request.path) {
        try HttpFileResponse.with(absolutePath: path, clientCache: .days(30))
    }
    return .notFound()
}

try server.start(8080)
RunLoop.main.run()
```

The generated Bootstrap page requests root-relative package assets such as `/bootstrap-5.3.1-dist/css/bootstrap.min.css`, `/jquery-3.6.1.min.js`, and `/webPageLoader.js`; the `notFoundHandler` above serves them. Custom app assets must be addressed by routes that map to their actual location. Do not expose the whole filesystem.

### Forms and server handling

`Form` builds Bootstrap-styled HTML and can be assigned to `page.body`. Server-side validation still belongs in Swifter handlers.

```swift
let form = Form(url: "/account", method: "POST", attributes: ["class": "needs-validation"])
    .addInputText(
        name: "displayName",
        label: "Display name",
        attributes: ["required": "required", "autocomplete": "name"]
    )
    .addSelect(
        name: "plan",
        label: "Plan",
        options: [
            FormSelectModel(label: "Free", value: "free"),
            FormSelectModel(label: "Pro", value: "pro")
        ],
        selected: "free"
    )
    .addSubmit(name: "save", label: "Save", style: .primary)

server.get["account"] = { _, _ in
    let page = BootstrapTemplate()
    page.title = "Account"
    page.body = form
    return .ok(.html(page))
}

struct AccountInput: Decodable {
    let displayName: String
    let plan: String
}

server.post["account"] = { request, _ in
    do {
        let input = try request.formData.decode(AccountInput.self)
        // Validate authorization and business rules before persisting input.
        return .ok(.text("Saved \(input.displayName)"))
    } catch {
        return .badRequest(.text("Please complete every required field."))
    }
}
```

All form methods return the same `Form`, enabling fluent setup. Give an input an explicit `id` whenever JavaScript, tests, labels outside the form, or accessibility tooling needs a stable identifier. `addRaw(html:)` inserts unescaped HTML and must never receive untrusted input.

With `Form(ajax: true)`, the bundled helper submits a `POST` and expects JavaScript (`dataType: "script"`), regardless of the form method. Return `.js(JSResponse(...))` from that endpoint.

```swift
server.post["account/ajax"] = { request, _ in
    let input = try request.formData.decode(AccountInput.self)
    let script = JSResponse(
        .showSuccess("Saved \(input.displayName)"),
        .loadHtml(path: "/account/summary", domID: "#content")
    )
    return .ok(.js(script))
}
```

`JSCode.loadHtml` and `loadHtmlAndJS` require a CSS selector such as `"#content"`, not a bare DOM identifier. Do not use `JSCode.submitForm(path:domID:)` in BootstrapStarter 1.2.0: its current output is malformed. Prefer `Form(ajax: true)` or correctly escaped `.custom(code:)`.

### Application templates with Template.swift

Use Template.swift for small reusable fragments or views you own. A template uses `{name}` placeholders by default and `[START name]` / `[END name]` repeated sections.

```swift
import Template

let template = Template.load(relativePath: "templates/account.tpl.html")
template.assign("name", "Ada")
template.assign(["label": "Notifications"], inNest: "setting")

server.get["account/fragment"] = { _, _ in
    .ok(.html(template))
}
```

`Template.load(relativePath:)` resolves below `Resources` in the current working directory. `Template.cached` retains file contents in a process-wide cache and is best for immutable production templates; `Template.load` reads fresh content. Call `reset()` before reusing a mutable template instance. Render user-controlled values only after escaping for their exact HTML, attribute, CSS, or JavaScript context—neither Template.swift nor BootstrapStarter promises context-aware escaping.

### Web UI checklist

- Use BootstrapStarter pages for complete documents and Template.swift for application-owned templates.
- Serve BootstrapStarter assets only through `BootstrapTemplate.absolutePath(for:)`.
- Keep custom public assets under application `Resources`; never use the package bundle as an upload directory.
- Escape dynamic values at the output boundary and add CSRF protection, authentication, authorization, validation, and rate limiting in Swifter.
- Use a deliberate Content-Security-Policy. `addJS(code:)` and `addCSS(code:)` produce inline content, which may require nonces, hashes, or a suitably designed policy.
- Keep package resource bundles (`*.resources`) beside the executable when deploying SwiftPM applications.

## Docker deployment

This multi-stage example builds an executable target named `App` from a package whose source is at the repository root. It preserves every SwiftPM resource bundle (including BootstrapStarter assets), copies application resources, runs as an unprivileged user, and stops gracefully when `SIGTERM` is handled with `Process.watchSignals`.

```dockerfile
# syntax=docker/dockerfile:1
FROM swift:6.1 AS builder

WORKDIR /build

# Copy the manifest first to make dependency resolution cacheable.
COPY Package.swift ./
RUN swift package resolve

# Copy the application source and build an optimized executable.
COPY Sources ./Sources
COPY Resources ./Resources
RUN swift build -c release --product App

# Collect the executable plus all SwiftPM-generated resource bundles.
RUN bin_path="$(swift build -c release --show-bin-path)" \
    && mkdir -p /output \
    && cp "$bin_path/App" /output/App \
    && find "$bin_path" -maxdepth 1 -type d -name '*.resources' -exec cp -R {} /output/ \;

FROM swift:6.1-slim AS runtime

WORKDIR /app

# The executable, including dependency resource bundles.
COPY --from=builder /output/ ./
# Application-owned templates, images, CSS, and JavaScript loaded from /app/Resources.
COPY --from=builder /build/Resources ./Resources

CMD ["./App"]
```

If the application uses a native library such as `libgd`, install its runtime package in the runtime stage and its development package in the builder stage. Set timezone data only when the service genuinely needs it; otherwise keep the image minimal. Do not bake `.env` files, certificates, passwords, or API keys into the image—supply them through the deployment platform's secret mechanism.

For projects arranged as separate library and server directories, adjust the build-context copies and the `WORKDIR`, but keep the resource-bundle copy step. On ARM Linux, build for the image platform or pass the appropriate Swift target triple; common choices are `aarch64-unknown-linux-gnu` for Raspberry Pi-class 64-bit ARM and `x86_64-unknown-linux-gnu` for Intel/AMD64.

Run the test suite locally with `swift test`, or validate Linux compatibility with:

```bash
docker run --rm -t -v "$PWD":/workspace -w /workspace swift:6.1 \
  swift test --scratch-path /tmp/swifter-build-6.1 --no-parallel
```
