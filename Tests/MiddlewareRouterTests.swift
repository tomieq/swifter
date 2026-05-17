//
//  MiddlewareRouterTests.swift
//  Swifter
//
//  Created by Tomasz on 15/03/2025.
//

import XCTest
@testable import Swifter

class MiddlewareRouterTests: XCTestCase {
    var router: MiddlewareRouter!
    var registeredHandlers: [String] = []
    var invokedHandlers: [String] = []

    override func setUp() {
        super.setUp()
        self.router = MiddlewareRouter()
    }

    override func tearDown() {
        self.router = nil
        super.tearDown()
    }

    func testRouterForExactPath() {
        self.router.register(path: "admin", handler: self.makeHandler(id: "A"))
        self.invokeHandlers(path: "admin")
        XCTAssertEqual(self.invokedHandlers, ["A"])
    }

    func testRouterSingleWildcard() {
        self.router.register(path: "admin/*", handler: self.makeHandler(id: "A"))
        self.router.register(path: "admin/script.js", handler: self.makeHandler(id: "B"))

        // it should not invoke handler
        self.invokeHandlers(path: "admin")
        XCTAssertTrue(self.invokedHandlers.isEmpty)

        self.resetInvocations()
        self.invokeHandlers(path: "admin/index.html")
        XCTAssertEqual(self.invokedHandlers, ["A"])

        self.resetInvocations()
        self.invokeHandlers(path: "admin/script.js")
        // first general are invoked, then specified
        XCTAssertEqual(self.invokedHandlers, ["A", "B"])

        self.resetInvocations()
        self.invokeHandlers(path: "admin/nested/script.js")
        // it does not match single wildcard
        XCTAssertTrue(self.invokedHandlers.isEmpty)

        self.resetInvocations()
        self.invokeHandlers(path: "admin/nested/even/more/load.js")
        // it does not match single wildcard
        XCTAssertTrue(self.invokedHandlers.isEmpty)
    }

    func testRouterGreedyWildcard() {
        self.router.register(path: "admin/*", handler: self.makeHandler(id: "A"))
        self.router.register(path: "admin/**", handler: self.makeHandler(id: "B"))
        self.router.register(path: "admin/script.js", handler: self.makeHandler(id: "C"))
        self.router.register(path: "admin", handler: self.makeHandler(id: "D"))
        self.router.register(path: "admin/**/load.js", handler: self.makeHandler(id: "E"))
        self.router.register(path: "admin/nested", handler: self.makeHandler(id: "F"))

        self.resetInvocations()
        self.invokeHandlers(path: "admin")
        XCTAssertEqual(self.invokedHandlers, ["D"])

        self.resetInvocations()
        self.invokeHandlers(path: "/admin/index.html")
        XCTAssertEqual(self.invokedHandlers, ["B", "A"])

        self.resetInvocations()
        self.invokeHandlers(path: "admin/script.js")
        XCTAssertEqual(self.invokedHandlers, ["B", "A", "C"])

        self.resetInvocations()
        self.invokeHandlers(path: "admin/nested/script.js")
        XCTAssertEqual(self.invokedHandlers, ["B"])

        self.resetInvocations()
        self.invokeHandlers(path: "admin/nested/even/more/load.js")
        XCTAssertEqual(self.invokedHandlers, ["B", "E"])
    }

    func testMixedIssue() {
        self.router.register(path: "/**", handler: self.makeHandler(id: "0"))
        self.router.register(path: "admin/**", handler: self.makeHandler(id: "A"))
        self.router.register(path: "admin/*", handler: self.makeHandler(id: "B"))
        self.router.register(path: "admin/reset", handler: self.makeHandler(id: "C"))
        self.router.register(path: "admin/**/file.js", handler: self.makeHandler(id: "D"))

        self.resetInvocations()
        self.invokeHandlers(path: "admin/reset/a/file.js")
        XCTAssertEqual(self.invokedHandlers, ["0", "A", "D"])
    }

    private func makeHandler(id: String) -> HttpMiddlewareHandler {
        self.registeredHandlers.append(id)
        return { [unowned self] _, _ in
            self.invokedHandlers.append(id)
            return nil
        }
    }

    private func invokeHandlers(path: String) {
        self.router.layers(path: path).forEach {
            _ = try? $0(HttpRequest(socketID: UUID()), HttpResponseHeaders())
        }
    }

    private func resetInvocations() {
        self.invokedHandlers = []
    }
}
