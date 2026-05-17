//
//  MiddlewareRouterTests.swift
//  Swifter
//
//  Created by Tomasz on 15/03/2025.
//

import Foundation
import Testing
@testable import Swifter

@Suite struct MiddlewareRouterTests {
    @Test func routerForExactPath() {
        let fixture = MiddlewareRouterFixture()
        fixture.router.register(path: "admin", handler: fixture.makeHandler(id: "A"))
        fixture.invokeHandlers(path: "admin")
        #expect(fixture.invokedHandlers == ["A"])
    }

    @Test func routerSingleWildcard() {
        let fixture = MiddlewareRouterFixture()
        fixture.router.register(path: "admin/*", handler: fixture.makeHandler(id: "A"))
        fixture.router.register(path: "admin/script.js", handler: fixture.makeHandler(id: "B"))

        fixture.invokeHandlers(path: "admin")
        #expect(fixture.invokedHandlers.isEmpty)

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "admin/index.html")
        #expect(fixture.invokedHandlers == ["A"])

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "admin/script.js")
        #expect(fixture.invokedHandlers == ["A", "B"])

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "admin/nested/script.js")
        #expect(fixture.invokedHandlers.isEmpty)

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "admin/nested/even/more/load.js")
        #expect(fixture.invokedHandlers.isEmpty)
    }

    @Test func routerGreedyWildcard() {
        let fixture = MiddlewareRouterFixture()
        fixture.router.register(path: "admin/*", handler: fixture.makeHandler(id: "A"))
        fixture.router.register(path: "admin/**", handler: fixture.makeHandler(id: "B"))
        fixture.router.register(path: "admin/script.js", handler: fixture.makeHandler(id: "C"))
        fixture.router.register(path: "admin", handler: fixture.makeHandler(id: "D"))
        fixture.router.register(path: "admin/**/load.js", handler: fixture.makeHandler(id: "E"))
        fixture.router.register(path: "admin/nested", handler: fixture.makeHandler(id: "F"))

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "admin")
        #expect(fixture.invokedHandlers == ["D"])

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "/admin/index.html")
        #expect(fixture.invokedHandlers == ["B", "A"])

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "admin/script.js")
        #expect(fixture.invokedHandlers == ["B", "A", "C"])

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "admin/nested/script.js")
        #expect(fixture.invokedHandlers == ["B"])

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "admin/nested/even/more/load.js")
        #expect(fixture.invokedHandlers == ["B", "E"])
    }

    @Test func mixedIssue() {
        let fixture = MiddlewareRouterFixture()
        fixture.router.register(path: "/**", handler: fixture.makeHandler(id: "0"))
        fixture.router.register(path: "admin/**", handler: fixture.makeHandler(id: "A"))
        fixture.router.register(path: "admin/*", handler: fixture.makeHandler(id: "B"))
        fixture.router.register(path: "admin/reset", handler: fixture.makeHandler(id: "C"))
        fixture.router.register(path: "admin/**/file.js", handler: fixture.makeHandler(id: "D"))

        fixture.resetInvocations()
        fixture.invokeHandlers(path: "admin/reset/a/file.js")
        #expect(fixture.invokedHandlers == ["0", "A", "D"])
    }
}

private final class MiddlewareRouterFixture {
    let router = MiddlewareRouter()
    var registeredHandlers: [String] = []
    var invokedHandlers: [String] = []

    func makeHandler(id: String) -> HttpMiddlewareHandler {
        self.registeredHandlers.append(id)
        return { _, _ in
            self.invokedHandlers.append(id)
            return nil
        }
    }

    func invokeHandlers(path: String) {
        self.router.layers(path: path).forEach {
            _ = try? $0(HttpRequest(socketID: UUID()), HttpResponseHeaders())
        }
    }

    func resetInvocations() {
        self.invokedHandlers = []
    }
}
