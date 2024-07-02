//
//  SwifterTestsHttpRouter.swift
//  Swifter
//

//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

import XCTest
@testable import Swifter

class SwifterTestsHttpRouter: XCTestCase {

    var router: HttpRouter!

    override func setUp() {
        super.setUp()
        router = HttpRouter()
    }

    override func tearDown() {
        router = nil
        super.tearDown()
    }

    func testHttpRouterSlashRoot() {

        router.register(nil, path: "/", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNotNil(router.route(nil, path: "/"))
    }

    func testHttpRouterSimplePathSegments() {

        router.register(nil, path: "/a/b/c/d", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(router.route(nil, path: "/"))
        XCTAssertNil(router.route(nil, path: "/a"))
        XCTAssertNil(router.route(nil, path: "/a/b"))
        XCTAssertNil(router.route(nil, path: "/a/b/c"))
        XCTAssertNotNil(router.route(nil, path: "/a/b/c/d"))
    }

    func testHttpRouterSinglePathSegmentWildcard() {

        router.register(nil, path: "/a/*/c/d", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(router.route(nil, path: "/"))
        XCTAssertNil(router.route(nil, path: "/a"))
        XCTAssertNotNil(router.route(nil, path: "/a/foo/c/d"))
        XCTAssertNotNil(router.route(nil, path: "/a/b/c/d"))
        XCTAssertNil(router.route(nil, path: "/a/b"))
        XCTAssertNil(router.route(nil, path: "/a/b/foo/d"))
    }

    func testHttpRouterVariables() {

        router.register(nil, path: "/a/:arg1/:arg2/b/c/d/:arg3", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(router.route(nil, path: "/"))
        XCTAssertNil(router.route(nil, path: "/a"))
        XCTAssertNil(router.route(nil, path: "/a/b/c/d"))
        XCTAssertEqual(router.route(nil, path: "/a/value1/value2/b/c/d/value3")?.0[":arg1"], "value1")
        XCTAssertEqual(router.route(nil, path: "/a/value1/value2/b/c/d/value3")?.0[":arg2"], "value2")
        XCTAssertEqual(router.route(nil, path: "/a/value1/value2/b/c/d/value3")?.0[":arg3"], "value3")
    }

    func testHttpRouterMultiplePathSegmentWildcards() {

        router.register(nil, path: "/a/**/e/f/g", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(router.route(nil, path: "/"))
        XCTAssertNil(router.route(nil, path: "/a"))
        XCTAssertNotNil(router.route(nil, path: "/a/b/c/d/e/f/g"))
        XCTAssertNil(router.route(nil, path: "/a/e/f/g"))
    }
    
    func testHttpRouterMultiplePathSegmentWildcardTail() {

        router.register(nil, path: "/a/b/**", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(router.route(nil, path: "/"))
        XCTAssertNil(router.route(nil, path: "/a"))
        XCTAssertNotNil(router.route(nil, path: "/a/b/c/d/e/f/g"))
        XCTAssertNil(router.route(nil, path: "/a/e/f/g"))
    }

    func testHttpRouterEmptyTail() {

        router.register(nil, path: "/a/b/", handler: { _, _ in
            return .ok(.html("OK"))
        })

        router.register(nil, path: "/a/b/:var", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(router.route(nil, path: "/"))
        XCTAssertNil(router.route(nil, path: "/a"))
        XCTAssertNotNil(router.route(nil, path: "/a/b/"))
        XCTAssertNil(router.route(nil, path: "/a/e/f/g"))

        XCTAssertEqual(router.route(nil, path: "/a/b/value1")?.0[":var"], "value1")

        XCTAssertEqual(router.route(nil, path: "/a/b/")?.0[":var"], nil)
    }

    func testHttpRouterPercentEncodedPathSegments() {

        router.register(nil, path: "/a/<>/^", handler: { _, _ in
            return .ok(.html("OK"))
        })

        XCTAssertNil(router.route(nil, path: "/"))
        XCTAssertNil(router.route(nil, path: "/a"))
        XCTAssertNotNil(router.route(nil, path: "/a/%3C%3E/%5E"))
    }

    func testHttpRouterHandlesOverlappingPaths() throws {

        let request = HttpRequest()

        let staticRouteExpectation = expectation(description: "Static Route")
        var foundStaticRoute = false
        router.register(.GET, path: "a/b") { _, _ in
            foundStaticRoute = true
            staticRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let variableRouteExpectation = expectation(description: "Variable Route")
        var foundVariableRoute = false
        router.register(.GET, path: "a/:id/c") { _, _ in
            foundVariableRoute = true
            variableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let staticRouteResult = router.route(HttpMethod.GET, path: "a/b")
        let staticRouterHandler = staticRouteResult?.1
        XCTAssertNotNil(staticRouteResult)
        _ = try staticRouterHandler?(request, HttpResponseHeaders())

        let variableRouteResult = router.route(.GET, path: "a/b/c")
        let variableRouterHandler = variableRouteResult?.1
        XCTAssertNotNil(variableRouteResult)
        _ = try variableRouterHandler?(request, HttpResponseHeaders())

        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertTrue(foundStaticRoute)
        XCTAssertTrue(foundVariableRoute)
    }

    func testHttpRouterHandlesOverlappingPathsInDynamicRoutes() throws {

        let request = HttpRequest()

        let firstVariableRouteExpectation = expectation(description: "First Variable Route")
        var foundFirstVariableRoute = false
        router.register(.GET, path: "a/:id") { _, _ in
            foundFirstVariableRoute = true
            firstVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let secondVariableRouteExpectation = expectation(description: "Second Variable Route")
        var foundSecondVariableRoute = false
        router.register(.GET, path: "a/:id/c") { _, _ in
            foundSecondVariableRoute = true
            secondVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let firstRouteResult = router.route(.GET, path: "a/b")
        let firstRouterHandler = firstRouteResult?.1
        XCTAssertNotNil(firstRouteResult)
        _ = try firstRouterHandler?(request, HttpResponseHeaders())

        let secondRouteResult = router.route(.GET, path: "a/b/c")
        let secondRouterHandler = secondRouteResult?.1
        XCTAssertNotNil(secondRouteResult)
        _ = try secondRouterHandler?(request, HttpResponseHeaders())

        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertTrue(foundFirstVariableRoute)
        XCTAssertTrue(foundSecondVariableRoute)
    }

    func testHttpRouterShouldHandleOverlappingRoutesInTrail() throws {

        let request = HttpRequest()

        let firstVariableRouteExpectation = expectation(description: "First Variable Route")
        var foundFirstVariableRoute = false
        router.register(.GET, path: "/a/:id") { _, _ in
            foundFirstVariableRoute = true
            firstVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let secondVariableRouteExpectation = expectation(description: "Second Variable Route")
        var foundSecondVariableRoute = false
        router.register(.GET, path: "/a") { _, _ in
            foundSecondVariableRoute = true
            secondVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let thirdVariableRouteExpectation = expectation(description: "Third Variable Route")
        var foundThirdVariableRoute = false
        router.register(.GET, path: "/a/:id/b") { _, _ in
            foundThirdVariableRoute = true
            thirdVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let firstRouteResult = router.route(.GET, path: "/a")
        let firstRouterHandler = firstRouteResult?.1
        XCTAssertNotNil(firstRouteResult)
        _ = try firstRouterHandler?(request, HttpResponseHeaders())

        let secondRouteResult = router.route(.GET, path: "/a/b")
        let secondRouterHandler = secondRouteResult?.1
        XCTAssertNotNil(secondRouteResult)
        _ = try secondRouterHandler?(request, HttpResponseHeaders())

        let thirdRouteResult = router.route(.GET, path: "/a/b/b")
        let thirdRouterHandler = thirdRouteResult?.1
        XCTAssertNotNil(thirdRouteResult)
        _ = try thirdRouterHandler?(request, HttpResponseHeaders())

        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertTrue(foundFirstVariableRoute)
        XCTAssertTrue(foundSecondVariableRoute)
        XCTAssertTrue(foundThirdVariableRoute)
    }

    func testHttpRouterHandlesOverlappingPathsInDynamicRoutesInTheMiddle() throws {

        let request = HttpRequest()

        let firstVariableRouteExpectation = expectation(description: "First Variable Route")
        var foundFirstVariableRoute = false
        router.register(.GET, path: "/a/b/c/d/e") { _, _ in
            foundFirstVariableRoute = true
            firstVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let secondVariableRouteExpectation = expectation(description: "Second Variable Route")
        var foundSecondVariableRoute = false
        router.register(.GET, path: "/a/:id/f/g") { _, _ in
            foundSecondVariableRoute = true
            secondVariableRouteExpectation.fulfill()
            return HttpResponse.accepted()
        }

        let firstRouteResult = router.route(.GET, path: "/a/b/c/d/e")
        let firstRouterHandler = firstRouteResult?.1
        XCTAssertNotNil(firstRouteResult)
        _ = try firstRouterHandler?(request, HttpResponseHeaders())

        let secondRouteResult = router.route(.GET, path: "/a/b/f/g")
        let secondRouterHandler = secondRouteResult?.1
        XCTAssertNotNil(secondRouteResult)
        _ = try secondRouterHandler?(request, HttpResponseHeaders())

        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertTrue(foundFirstVariableRoute)
        XCTAssertTrue(foundSecondVariableRoute)
    }
}
