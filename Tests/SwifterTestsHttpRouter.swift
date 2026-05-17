//
//  SwifterTestsHttpRouter.swift
//  Swifter
//

//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

import XCTest
import Foundation
import Dispatch
@testable import Swifter

class SwifterTestsHttpRouter: XCTestCase {
    var router: HttpRouter!

    override func setUp() {
        super.setUp()
        self.router = HttpRouter()
    }

    override func tearDown() {
        self.router = nil
        super.tearDown()
    }

    func testHttpRouterSlashRoot() {
        self.router.register(nil, path: "/", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNotNil(self.router.route(nil, path: "/"))
    }

    func testHttpRouterSimplePathSegments() {
        self.router.register(nil, path: "/a/b/c/d", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(self.router.route(nil, path: "/"))
        XCTAssertNil(self.router.route(nil, path: "/a"))
        XCTAssertNil(self.router.route(nil, path: "/a/b"))
        XCTAssertNil(self.router.route(nil, path: "/a/b/c"))
        XCTAssertNotNil(self.router.route(nil, path: "/a/b/c/d"))
    }

    func testHttpRouterSinglePathSegmentWildcard() {
        self.router.register(nil, path: "/a/*/c/d", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(self.router.route(nil, path: "/"))
        XCTAssertNil(self.router.route(nil, path: "/a"))
        XCTAssertNotNil(self.router.route(nil, path: "/a/foo/c/d"))
        XCTAssertNotNil(self.router.route(nil, path: "/a/b/c/d"))
        XCTAssertNil(self.router.route(nil, path: "/a/b"))
        XCTAssertNil(self.router.route(nil, path: "/a/b/foo/d"))
    }

    func testHttpRouterVariables() {
        self.router.register(nil, path: "/a/:arg1/:arg2/b/c/d/:arg3", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(self.router.route(nil, path: "/"))
        XCTAssertNil(self.router.route(nil, path: "/a"))
        XCTAssertNil(self.router.route(nil, path: "/a/b/c/d"))
        XCTAssertEqual(self.router.route(nil, path: "/a/value1/value2/b/c/d/value3")?.0["arg1"], "value1")
        XCTAssertEqual(self.router.route(nil, path: "/a/value1/value2/b/c/d/value3")?.0["arg2"], "value2")
        XCTAssertEqual(self.router.route(nil, path: "/a/value1/value2/b/c/d/value3")?.0["arg3"], "value3")
    }

    func testHttpRouterMultiplePathSegmentWildcards() {
        self.router.register(nil, path: "/a/**/e/f/g", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(self.router.route(nil, path: "/"))
        XCTAssertNil(self.router.route(nil, path: "/a"))
        XCTAssertNotNil(self.router.route(nil, path: "/a/b/c/d/e/f/g"))
        XCTAssertNotNil(self.router.route(nil, path: "/a/b/c/e/f/g"))
        XCTAssertNil(self.router.route(nil, path: "/a/e/f/g"))
    }

    func testHttpRouterMultiplePathSegmentWildcardTail() {
        self.router.register(nil, path: "/a/b/**", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(self.router.route(nil, path: "/"))
        XCTAssertNil(self.router.route(nil, path: "/a"))
        XCTAssertNotNil(self.router.route(nil, path: "/a/b/c/d/e/f/g"))
        XCTAssertNil(self.router.route(nil, path: "/a/e/f/g"))
    }

    func testHttpRouterEmptyTail() {
        self.router.register(nil, path: "/a/b/", handler: { _, _ in
            return .ok(.html("OK"))
        })

        self.router.register(nil, path: "/a/b/:var", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(self.router.route(nil, path: "/"))
        XCTAssertNil(self.router.route(nil, path: "/a"))
        XCTAssertNotNil(self.router.route(nil, path: "/a/b/"))
        XCTAssertNil(self.router.route(nil, path: "/a/e/f/g"))

        XCTAssertEqual(self.router.route(nil, path: "/a/b/value1")?.0["var"], "value1")

        XCTAssertEqual(self.router.route(nil, path: "/a/b/")?.0["var"], nil)
    }

    func testHttpRouterPercentEncodedPathSegments() {
        self.router.register(nil, path: "/a/<>/^", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(self.router.route(nil, path: "/"))
        XCTAssertNil(self.router.route(nil, path: "/a"))
        XCTAssertNotNil(self.router.route(nil, path: "/a/%3C%3E/%5E"))
    }

    func testHttpRouterHandlesOverlappingPaths() throws {
        let request = HttpRequest(socketID: UUID())

        let staticRouteExpectation = expectation(description: "Static Route")
        var foundStaticRoute = false
        self.router.register(.GET, path: "a/b") { _, _ in
            foundStaticRoute = true
            staticRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let variableRouteExpectation = expectation(description: "Variable Route")
        var foundVariableRoute = false
        self.router.register(.GET, path: "a/:id/c") { _, _ in
            foundVariableRoute = true
            variableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let staticRouteResult = self.router.route(HttpMethod.GET, path: "a/b")
        let staticRouterHandler = staticRouteResult?.1
        XCTAssertNotNil(staticRouteResult)
        try self.invoke(staticRouterHandler, request, HttpResponseHeaders())

        let variableRouteResult = self.router.route(.GET, path: "a/b/c")
        let variableRouterHandler = variableRouteResult?.1
        XCTAssertNotNil(variableRouteResult)
        try self.invoke(variableRouterHandler, request, HttpResponseHeaders())

        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertTrue(foundStaticRoute)
        XCTAssertTrue(foundVariableRoute)
    }

    func testHttpRouterHandlesOverlappingPathsInDynamicRoutes() throws {
        let request = HttpRequest(socketID: UUID())

        let firstVariableRouteExpectation = expectation(description: "First Variable Route")
        var foundFirstVariableRoute = false
        self.router.register(.GET, path: "a/:id") { _, _ in
            foundFirstVariableRoute = true
            firstVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let secondVariableRouteExpectation = expectation(description: "Second Variable Route")
        var foundSecondVariableRoute = false
        self.router.register(.GET, path: "a/:id/c") { _, _ in
            foundSecondVariableRoute = true
            secondVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let firstRouteResult = self.router.route(.GET, path: "a/b")
        let firstRouterHandler = firstRouteResult?.1
        XCTAssertNotNil(firstRouteResult)
        try self.invoke(firstRouterHandler, request, HttpResponseHeaders())

        let secondRouteResult = self.router.route(.GET, path: "a/b/c")
        let secondRouterHandler = secondRouteResult?.1
        XCTAssertNotNil(secondRouteResult)
        try self.invoke(secondRouterHandler, request, HttpResponseHeaders())

        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertTrue(foundFirstVariableRoute)
        XCTAssertTrue(foundSecondVariableRoute)
    }

    func testHttpRouterShouldHandleOverlappingRoutesInTrail() throws {
        let request = HttpRequest(socketID: UUID())

        let firstVariableRouteExpectation = expectation(description: "First Variable Route")
        var foundFirstVariableRoute = false
        self.router.register(.GET, path: "/a/:id") { _, _ in
            foundFirstVariableRoute = true
            firstVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let secondVariableRouteExpectation = expectation(description: "Second Variable Route")
        var foundSecondVariableRoute = false
        self.router.register(.GET, path: "/a") { _, _ in
            foundSecondVariableRoute = true
            secondVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let thirdVariableRouteExpectation = expectation(description: "Third Variable Route")
        var foundThirdVariableRoute = false
        self.router.register(.GET, path: "/a/:id/b") { _, _ in
            foundThirdVariableRoute = true
            thirdVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let firstRouteResult = self.router.route(.GET, path: "/a")
        let firstRouterHandler = firstRouteResult?.1
        XCTAssertNotNil(firstRouteResult)
        try self.invoke(firstRouterHandler, request, HttpResponseHeaders())

        let secondRouteResult = self.router.route(.GET, path: "/a/b")
        let secondRouterHandler = secondRouteResult?.1
        XCTAssertNotNil(secondRouteResult)
        try self.invoke(secondRouterHandler, request, HttpResponseHeaders())

        let thirdRouteResult = self.router.route(.GET, path: "/a/b/b")
        let thirdRouterHandler = thirdRouteResult?.1
        XCTAssertNotNil(thirdRouteResult)
        try self.invoke(thirdRouterHandler, request, HttpResponseHeaders())

        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertTrue(foundFirstVariableRoute)
        XCTAssertTrue(foundSecondVariableRoute)
        XCTAssertTrue(foundThirdVariableRoute)
    }

    func testHttpRouterHandlesOverlappingPathsInDynamicRoutesInTheMiddle() throws {
        let request = HttpRequest(socketID: UUID())

        let firstVariableRouteExpectation = expectation(description: "First Variable Route")
        var foundFirstVariableRoute = false
        self.router.register(.GET, path: "/a/b/c/d/e") { _, _ in
            foundFirstVariableRoute = true
            firstVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let secondVariableRouteExpectation = expectation(description: "Second Variable Route")
        var foundSecondVariableRoute = false
        self.router.register(.GET, path: "/a/:id/f/g") { _, _ in
            foundSecondVariableRoute = true
            secondVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let firstRouteResult = self.router.route(.GET, path: "/a/b/c/d/e")
        let firstRouterHandler = firstRouteResult?.1
        XCTAssertNotNil(firstRouteResult)
        try self.invoke(firstRouterHandler, request, HttpResponseHeaders())

        let secondRouteResult = self.router.route(.GET, path: "/a/b/f/g")
        let secondRouterHandler = secondRouteResult?.1
        XCTAssertNotNil(secondRouteResult)
        try self.invoke(secondRouterHandler, request, HttpResponseHeaders())

        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertTrue(foundFirstVariableRoute)
        XCTAssertTrue(foundSecondVariableRoute)
    }

    private func invoke(_ handler: HttpRequestHandler?, _ request: HttpRequest, _ headers: HttpResponseHeaders) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let resultStore = InvocationResultStore()
        let operation = {
            do {
                resultStore.store(.success(try await handler?(request, headers)))
            } catch {
                resultStore.store(.failure(error))
            }
            semaphore.signal()
        }
        #if compiler(>=6.0)
        Task.detached(operation: operation)
        #else
        Task {
            await operation()
        }
        #endif
        semaphore.wait()
        if case .failure(let error) = resultStore.load() {
            throw error
        }
    }

    private final class InvocationResultStore: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<HttpResponse?, Error>?

        func store(_ result: Result<HttpResponse?, Error>) {
            self.lock.lock()
            self.result = result
            self.lock.unlock()
        }

        func load() -> Result<HttpResponse?, Error>? {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.result
        }
    }
}
