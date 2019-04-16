#if !canImport(ObjectiveC)
import XCTest

extension IOSafetyTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__IOSafetyTests = [
        ("testStopWithActiveConnections", testStopWithActiveConnections),
    ]
}

extension MimeTypeTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__MimeTypeTests = [
        ("testCaseInsensitivity", testCaseInsensitivity),
        ("testCorrectTypes", testCorrectTypes),
        ("testDefaultValue", testDefaultValue),
        ("testTypeExtension", testTypeExtension),
    ]
}

extension ServerThreadingTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__ServerThreadingTests = [
        ("testShouldHandleTheSameRequestConcurrently", testShouldHandleTheSameRequestConcurrently),
        ("testShouldHandleTheSameRequestWithDifferentTimeIntervals", testShouldHandleTheSameRequestWithDifferentTimeIntervals),
    ]
}

extension SwifterTestsHttpParser {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__SwifterTestsHttpParser = [
        ("testParser", testParser),
    ]
}

extension SwifterTestsHttpResponseBody {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__SwifterTestsHttpResponseBody = [
        ("testArrayAsJSONPayload", testArrayAsJSONPayload),
        ("testDictionaryAsJSONPayload", testDictionaryAsJSONPayload),
        ("testNSArrayAsJSONPayload", testNSArrayAsJSONPayload),
        ("testNSDictionaryAsJSONPayload", testNSDictionaryAsJSONPayload),
    ]
}

extension SwifterTestsHttpRouter {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__SwifterTestsHttpRouter = [
        ("testHttpRouterEmptyTail", testHttpRouterEmptyTail),
        ("testHttpRouterHandlesOverlappingPaths", testHttpRouterHandlesOverlappingPaths),
        ("testHttpRouterHandlesOverlappingPathsInDynamicRoutes", testHttpRouterHandlesOverlappingPathsInDynamicRoutes),
        ("testHttpRouterHandlesOverlappingPathsInDynamicRoutesInTheMiddle", testHttpRouterHandlesOverlappingPathsInDynamicRoutesInTheMiddle),
        ("testHttpRouterMultiplePathSegmentWildcards", testHttpRouterMultiplePathSegmentWildcards),
        ("testHttpRouterPercentEncodedPathSegments", testHttpRouterPercentEncodedPathSegments),
        ("testHttpRouterShouldHandleOverlappingRoutesInTrail", testHttpRouterShouldHandleOverlappingRoutesInTrail),
        ("testHttpRouterSimplePathSegments", testHttpRouterSimplePathSegments),
        ("testHttpRouterSinglePathSegmentWildcard", testHttpRouterSinglePathSegmentWildcard),
        ("testHttpRouterSlashRoot", testHttpRouterSlashRoot),
        ("testHttpRouterVariables", testHttpRouterVariables),
    ]
}

extension SwifterTestsStringExtensions {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__SwifterTestsStringExtensions = [
        ("testBASE64", testBASE64),
        ("testMiscRemovePercentEncoding", testMiscRemovePercentEncoding),
        ("testMiscReplace", testMiscReplace),
        ("testMiscTrim", testMiscTrim),
        ("testMiscUnquote", testMiscUnquote),
        ("testSHA1", testSHA1),
    ]
}

extension SwifterTestsWebSocketSession {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__SwifterTestsWebSocketSession = [
        ("testParser", testParser),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(MimeTypeTests.__allTests__MimeTypeTests),
        testCase(ServerThreadingTests.__allTests__ServerThreadingTests),
        testCase(SwifterTestsHttpParser.__allTests__SwifterTestsHttpParser),
        testCase(SwifterTestsHttpResponseBody.__allTests__SwifterTestsHttpResponseBody),
        testCase(SwifterTestsHttpRouter.__allTests__SwifterTestsHttpRouter),
        testCase(SwifterTestsStringExtensions.__allTests__SwifterTestsStringExtensions),
        testCase(SwifterTestsWebSocketSession.__allTests__SwifterTestsWebSocketSession),
    ]
}
#endif
