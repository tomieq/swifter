//
//  HttpRequestTests.swift
//
//
//  Created by Tomasz on 25/05/2024.
//

import Foundation
import Testing
@testable import Swifter

@Suite struct HttpRequestTests {
    @Test func formData() throws {
        struct FormData: Codable {
            let user: String
            let password: Int
        }
        let request = HttpRequest(socketID: UUID())
        request.headers = HttpRequestHeaderParams(["content-type": "application/x-www-form-urlencoded"])
        request.body = HttpRequestBody([UInt8]("user=John&password=1234".data(using: .utf8)!))
        let formData: FormData? = try request.formData.decode()
        #expect(formData?.user == "John")
        #expect(formData?.password == 1234)
    }

    @Test func queryParams() throws {
        struct Search: Codable {
            let limit: Int
            let start: Int
            let query: String
        }
        let request = HttpRequest(socketID: UUID())
        request.queryParams = HttpRequestParams(["limit": "10", "query": "Warsaw", "start": "900"])
        let search: Search? = try request.queryParams.decode()
        #expect(search?.limit == 10)
        #expect(search?.query == "Warsaw")
        #expect(search?.start == 900)
    }

    @Test func decodePathParams() async throws {
        struct Book: Codable {
            let id: Int
            let title: String
        }
        let server = HttpServer()
        let expectedBook = LockedValue<Book>()
        server.get["book/:id/:title"] = { request, _ in
            guard let book: Book = try? request.pathParams.decode() else {
                return .badRequest(.text("Invalid url"))
            }
            expectedBook.set(book)
            return .ok(.text("Title: \(book.title)"))
        }
        defer {
            stop(server)
        }
        let binding = ServerBinding.make()
        try server.start(binding.port)
        _ = try await DefaultSession().request(url: binding.host.appendingPathComponent("book/34/esmeralda"))
        #expect(expectedBook.value?.id == 34)
        #expect(expectedBook.value?.title == "esmeralda")
    }
}
