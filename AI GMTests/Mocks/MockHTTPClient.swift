//
//  MockHTTPClient.swift
//  AI GMTests
//

import Foundation
@testable import AI_GM

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    private var responses: [(Data, URLResponse)] = []
    private var errors: [Error?] = []
    private(set) var requestCount = 0

    func enqueueResponse(data: Data, statusCode: Int, url: URL = URL(string: "https://test.com")!) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        responses.append((data, response))
        errors.append(nil)
    }

    func enqueueError(_ error: Error) {
        responses.append((Data(), URLResponse()))
        errors.append(error)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let index = requestCount
        requestCount += 1

        guard index < responses.count else {
            fatalError("MockHTTPClient: no more queued responses (request #\(index + 1))")
        }

        if let error = errors[index] {
            throw error
        }

        return responses[index]
    }
}
