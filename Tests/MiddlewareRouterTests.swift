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
    @Test func routerForExactPath() async {
        let fixture = MiddlewareRouterFixture()
        fixture.router.register(path: "admin", handler: fixture.makeHandler(id: "A"))
        await fixture.invokeHandlers(path: "admin")
        #expect(fixture.invokedHandlers == ["A"])
    }

    @Test func routerSingleWildcard() async {
        let fixture = MiddlewareRouterFixture()
        fixture.router.register(path: "admin/*", handler: fixture.makeHandler(id: "A"))
        fixture.router.register(path: "admin/script.js", handler: fixture.makeHandler(id: "B"))

        await fixture.invokeHandlers(path: "admin")
        #expect(fixture.invokedHandlers.isEmpty)

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "admin/index.html")
        #expect(fixture.invokedHandlers == ["A"])

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "admin/script.js")
        #expect(fixture.invokedHandlers == ["A", "B"])

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "admin/nested/script.js")
        #expect(fixture.invokedHandlers.isEmpty)

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "admin/nested/even/more/load.js")
        #expect(fixture.invokedHandlers.isEmpty)
    }

    @Test func routerGreedyWildcard() async {
        let fixture = MiddlewareRouterFixture()
        fixture.router.register(path: "admin/*", handler: fixture.makeHandler(id: "A"))
        fixture.router.register(path: "admin/**", handler: fixture.makeHandler(id: "B"))
        fixture.router.register(path: "admin/script.js", handler: fixture.makeHandler(id: "C"))
        fixture.router.register(path: "admin", handler: fixture.makeHandler(id: "D"))
        fixture.router.register(path: "admin/**/load.js", handler: fixture.makeHandler(id: "E"))
        fixture.router.register(path: "admin/nested", handler: fixture.makeHandler(id: "F"))

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "admin")
        #expect(fixture.invokedHandlers == ["D"])

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "/admin/index.html")
        #expect(fixture.invokedHandlers == ["B", "A"])

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "admin/script.js")
        #expect(fixture.invokedHandlers == ["B", "A", "C"])

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "admin/nested/script.js")
        #expect(fixture.invokedHandlers == ["B"])

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "admin/nested/even/more/load.js")
        #expect(fixture.invokedHandlers == ["B", "E"])
    }

    @Test func mixedIssue() async {
        let fixture = MiddlewareRouterFixture()
        fixture.router.register(path: "/**", handler: fixture.makeHandler(id: "0"))
        fixture.router.register(path: "admin/**", handler: fixture.makeHandler(id: "A"))
        fixture.router.register(path: "admin/*", handler: fixture.makeHandler(id: "B"))
        fixture.router.register(path: "admin/reset", handler: fixture.makeHandler(id: "C"))
        fixture.router.register(path: "admin/**/file.js", handler: fixture.makeHandler(id: "D"))

        fixture.resetInvocations()
        await fixture.invokeHandlers(path: "admin/reset/a/file.js")
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

    func invokeHandlers(path: String) async {
        for layer in self.router.layers(path: path) {
            _ = try? await layer(HttpRequest(socketID: UUID()), HttpResponseHeaders())
        }
    }

    func resetInvocations() {
        self.invokedHandlers = []
    }
}
