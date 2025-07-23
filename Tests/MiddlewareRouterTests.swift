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
        router = MiddlewareRouter()
    }
    
    override func tearDown() {
        router = nil
        super.tearDown()
    }
    
    func testRouterForExactPath() {
        router.register(path: "admin", handler: makeHandler(id: "A"))
        invokeHandlers(path: "admin")
        XCTAssertEqual(invokedHandlers, ["A"])
    }
    
    func testRouterSingleWildcard() {
        router.register(path: "admin/*", handler: makeHandler(id: "A"))
        router.register(path: "admin/script.js", handler: makeHandler(id: "B"))
        
        // it should not invoke handler
        invokeHandlers(path: "admin")
        XCTAssertTrue(invokedHandlers.isEmpty)
        
        resetInvocations()
        invokeHandlers(path: "admin/index.html")
        XCTAssertEqual(invokedHandlers, ["A"])
        
        resetInvocations()
        invokeHandlers(path: "admin/script.js")
        // first general are invoked, then specified
        XCTAssertEqual(invokedHandlers, ["A", "B"])
        
        resetInvocations()
        invokeHandlers(path: "admin/nested/script.js")
        // it does not match single wildcard
        XCTAssertTrue(invokedHandlers.isEmpty)

        resetInvocations()
        invokeHandlers(path: "admin/nested/even/more/load.js")
        // it does not match single wildcard
        XCTAssertTrue(invokedHandlers.isEmpty)
    }
    
    func testRouterGreedyWildcard() {
        router.register(path: "admin/*", handler: makeHandler(id: "A"))
        router.register(path: "admin/**", handler: makeHandler(id: "B"))
        router.register(path: "admin/script.js", handler: makeHandler(id: "C"))
        router.register(path: "admin", handler: makeHandler(id: "D"))
        router.register(path: "admin/**/load.js", handler: makeHandler(id: "E"))
        router.register(path: "admin/nested", handler: makeHandler(id: "F"))
    
        resetInvocations()
        invokeHandlers(path: "admin")
        XCTAssertEqual(invokedHandlers, ["D"])
        
        resetInvocations()
        invokeHandlers(path: "/admin/index.html")
        XCTAssertEqual(invokedHandlers, ["B", "A"])
        
        resetInvocations()
        invokeHandlers(path: "admin/script.js")
        XCTAssertEqual(invokedHandlers, ["B", "A", "C"])
        
        resetInvocations()
        invokeHandlers(path: "admin/nested/script.js")
        XCTAssertEqual(invokedHandlers, ["B"])
        
        resetInvocations()
        invokeHandlers(path: "admin/nested/even/more/load.js")
        XCTAssertEqual(invokedHandlers, ["B", "E"])
    }
    
    func testMixedIssue() {
        router.register(path: "/**", handler: makeHandler(id: "0"))
        router.register(path: "admin/**", handler: makeHandler(id: "A"))
        router.register(path: "admin/*", handler: makeHandler(id: "B"))
        router.register(path: "admin/reset", handler: makeHandler(id: "C"))
        router.register(path: "admin/**/file.js", handler: makeHandler(id: "D"))
        
        resetInvocations()
        invokeHandlers(path: "admin/reset/a/file.js")
        XCTAssertEqual(invokedHandlers, ["0", "A", "D"])
    }
    
    private func makeHandler(id: String) -> HttpMiddlewareHandler {
        registeredHandlers.append(id)
        return { [unowned self ] _, _ in
            invokedHandlers.append(id)
            return nil
        }
    }
    
    private func invokeHandlers(path: String) {
        router.layers(path: path).forEach {
            _ = try? $0(HttpRequest(socketID: UUID()), HttpResponseHeaders())
        }
    }
    
    private func resetInvocations() {
        invokedHandlers = []
    }
}
