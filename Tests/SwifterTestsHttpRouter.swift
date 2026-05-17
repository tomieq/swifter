import Foundation
import Testing
@testable import Swifter

@Suite struct SwifterTestsHttpRouter {
    @Test func httpRouterSlashRoot() {
        let router = HttpRouter()
        router.register(nil, path: "/") { _, _ in .ok(.html("OK")) }

        #expect(router.route(nil, path: "/") != nil)
    }

    @Test func httpRouterSimplePathSegments() {
        let router = HttpRouter()
        router.register(nil, path: "/a/b/c/d") { _, _ in .ok(.html("OK")) }

        #expect(router.route(nil, path: "/") == nil)
        #expect(router.route(nil, path: "/a") == nil)
        #expect(router.route(nil, path: "/a/b") == nil)
        #expect(router.route(nil, path: "/a/b/c") == nil)
        #expect(router.route(nil, path: "/a/b/c/d") != nil)
    }

    @Test func httpRouterSinglePathSegmentWildcard() {
        let router = HttpRouter()
        router.register(nil, path: "/a/*/c/d") { _, _ in .ok(.html("OK")) }

        #expect(router.route(nil, path: "/") == nil)
        #expect(router.route(nil, path: "/a") == nil)
        #expect(router.route(nil, path: "/a/foo/c/d") != nil)
        #expect(router.route(nil, path: "/a/b/c/d") != nil)
        #expect(router.route(nil, path: "/a/b") == nil)
        #expect(router.route(nil, path: "/a/b/foo/d") == nil)
    }

    @Test func httpRouterVariables() {
        let router = HttpRouter()
        router.register(nil, path: "/a/:arg1/:arg2/b/c/d/:arg3") { _, _ in .ok(.html("OK")) }

        #expect(router.route(nil, path: "/") == nil)
        #expect(router.route(nil, path: "/a") == nil)
        #expect(router.route(nil, path: "/a/b/c/d") == nil)
        #expect(router.route(nil, path: "/a/value1/value2/b/c/d/value3")?.0["arg1"] == "value1")
        #expect(router.route(nil, path: "/a/value1/value2/b/c/d/value3")?.0["arg2"] == "value2")
        #expect(router.route(nil, path: "/a/value1/value2/b/c/d/value3")?.0["arg3"] == "value3")
    }

    @Test func httpRouterMultiplePathSegmentWildcards() {
        let router = HttpRouter()
        router.register(nil, path: "/a/**/e/f/g") { _, _ in .ok(.html("OK")) }

        #expect(router.route(nil, path: "/") == nil)
        #expect(router.route(nil, path: "/a") == nil)
        #expect(router.route(nil, path: "/a/b/c/d/e/f/g") != nil)
        #expect(router.route(nil, path: "/a/b/c/e/f/g") != nil)
        #expect(router.route(nil, path: "/a/e/f/g") == nil)
    }

    @Test func httpRouterMultiplePathSegmentWildcardTail() {
        let router = HttpRouter()
        router.register(nil, path: "/a/b/**") { _, _ in .ok(.html("OK")) }

        #expect(router.route(nil, path: "/") == nil)
        #expect(router.route(nil, path: "/a") == nil)
        #expect(router.route(nil, path: "/a/b/c/d/e/f/g") != nil)
        #expect(router.route(nil, path: "/a/e/f/g") == nil)
    }

    @Test func httpRouterEmptyTail() {
        let router = HttpRouter()
        router.register(nil, path: "/a/b/") { _, _ in .ok(.html("OK")) }
        router.register(nil, path: "/a/b/:var") { _, _ in .ok(.html("OK")) }

        #expect(router.route(nil, path: "/") == nil)
        #expect(router.route(nil, path: "/a") == nil)
        #expect(router.route(nil, path: "/a/b/") != nil)
        #expect(router.route(nil, path: "/a/e/f/g") == nil)
        #expect(router.route(nil, path: "/a/b/value1")?.0["var"] == "value1")
        #expect(router.route(nil, path: "/a/b/")?.0["var"] == nil)
    }

    @Test func httpRouterPercentEncodedPathSegments() {
        let router = HttpRouter()
        router.register(nil, path: "/a/<>/^") { _, _ in .ok(.html("OK")) }

        #expect(router.route(nil, path: "/") == nil)
        #expect(router.route(nil, path: "/a") == nil)
        #expect(router.route(nil, path: "/a/%3C%3E/%5E") != nil)
    }

    @Test func httpRouterHandlesOverlappingPaths() async throws {
        let router = HttpRouter()
        let request = HttpRequest(socketID: UUID())
        let foundStaticRoute = LockedValue<Bool>()
        let foundVariableRoute = LockedValue<Bool>()

        router.register(.GET, path: "a/b") { _, _ in
            foundStaticRoute.set(true)
            return HttpResponse.accepted()
        }
        router.register(.GET, path: "a/:id/c") { _, _ in
            foundVariableRoute.set(true)
            return HttpResponse.accepted()
        }

        let staticRouteResult = router.route(.GET, path: "a/b")
        #expect(staticRouteResult != nil)
        _ = try await staticRouteResult?.1(request, HttpResponseHeaders())

        let variableRouteResult = router.route(.GET, path: "a/b/c")
        #expect(variableRouteResult != nil)
        _ = try await variableRouteResult?.1(request, HttpResponseHeaders())

        #expect(foundStaticRoute.value == true)
        #expect(foundVariableRoute.value == true)
    }

    @Test func httpRouterHandlesOverlappingPathsInDynamicRoutes() async throws {
        let router = HttpRouter()
        let request = HttpRequest(socketID: UUID())
        let foundFirstVariableRoute = LockedValue<Bool>()
        let foundSecondVariableRoute = LockedValue<Bool>()

        router.register(.GET, path: "a/:id") { _, _ in
            foundFirstVariableRoute.set(true)
            return HttpResponse.accepted()
        }
        router.register(.GET, path: "a/:id/c") { _, _ in
            foundSecondVariableRoute.set(true)
            return HttpResponse.accepted()
        }

        let firstRouteResult = router.route(.GET, path: "a/b")
        #expect(firstRouteResult != nil)
        _ = try await firstRouteResult?.1(request, HttpResponseHeaders())

        let secondRouteResult = router.route(.GET, path: "a/b/c")
        #expect(secondRouteResult != nil)
        _ = try await secondRouteResult?.1(request, HttpResponseHeaders())

        #expect(foundFirstVariableRoute.value == true)
        #expect(foundSecondVariableRoute.value == true)
    }

    @Test func httpRouterShouldHandleOverlappingRoutesInTrail() async throws {
        let router = HttpRouter()
        let request = HttpRequest(socketID: UUID())
        let foundFirstVariableRoute = LockedValue<Bool>()
        let foundSecondVariableRoute = LockedValue<Bool>()
        let foundThirdVariableRoute = LockedValue<Bool>()

        router.register(.GET, path: "/a/:id") { _, _ in
            foundFirstVariableRoute.set(true)
            return HttpResponse.accepted()
        }
        router.register(.GET, path: "/a") { _, _ in
            foundSecondVariableRoute.set(true)
            return HttpResponse.accepted()
        }
        router.register(.GET, path: "/a/:id/b") { _, _ in
            foundThirdVariableRoute.set(true)
            return HttpResponse.accepted()
        }

        let firstRouteResult = router.route(.GET, path: "/a")
        #expect(firstRouteResult != nil)
        _ = try await firstRouteResult?.1(request, HttpResponseHeaders())

        let secondRouteResult = router.route(.GET, path: "/a/b")
        #expect(secondRouteResult != nil)
        _ = try await secondRouteResult?.1(request, HttpResponseHeaders())

        let thirdRouteResult = router.route(.GET, path: "/a/b/b")
        #expect(thirdRouteResult != nil)
        _ = try await thirdRouteResult?.1(request, HttpResponseHeaders())

        #expect(foundFirstVariableRoute.value == true)
        #expect(foundSecondVariableRoute.value == true)
        #expect(foundThirdVariableRoute.value == true)
    }

    @Test func httpRouterHandlesOverlappingPathsInDynamicRoutesInTheMiddle() async throws {
        let router = HttpRouter()
        let request = HttpRequest(socketID: UUID())
        let foundFirstVariableRoute = LockedValue<Bool>()
        let foundSecondVariableRoute = LockedValue<Bool>()

        router.register(.GET, path: "/a/b/c/d/e") { _, _ in
            foundFirstVariableRoute.set(true)
            return HttpResponse.accepted()
        }
        router.register(.GET, path: "/a/:id/f/g") { _, _ in
            foundSecondVariableRoute.set(true)
            return HttpResponse.accepted()
        }

        let firstRouteResult = router.route(.GET, path: "/a/b/c/d/e")
        #expect(firstRouteResult != nil)
        _ = try await firstRouteResult?.1(request, HttpResponseHeaders())

        let secondRouteResult = router.route(.GET, path: "/a/b/f/g")
        #expect(secondRouteResult != nil)
        _ = try await secondRouteResult?.1(request, HttpResponseHeaders())

        #expect(foundFirstVariableRoute.value == true)
        #expect(foundSecondVariableRoute.value == true)
    }
}