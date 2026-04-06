//
//  AIService.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

final class AIService {
    /// 較長的 timeout 以適應本地模型較慢的推理速度
    private static let requestTimeout: TimeInterval = 300
    struct Message {
        enum Role: String {
            case system
            case user
        }

        let role: Role
        let content: String
    }

    enum AIServiceError: Error {
        case invalidResponse
        case invalidURL
        case httpError(statusCode: Int, message: String?)
    }

    private let configuration: AIHostConfiguration

    init(configuration: AIHostConfiguration) {
        self.configuration = configuration
    }

    func sendMessage(messages: [Message]) async throws -> AIResponse {
        let content = try await sendRawJSON(messages: messages)
        guard let normalizedJSON = normalizeJSONObject(in: content),
              let data = normalizedJSON.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }
        return try JSONDecoder().decode(AIResponse.self, from: data)
    }

    func sendRawJSON(messages: [Message]) async throws -> String {
        guard let url = requestURL() else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout

        let trimmedAPIKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAPIKey.isEmpty {
            request.addValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")
        }

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(messages: messages))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw AIServiceError.httpError(
                statusCode: httpResponse.statusCode,
                message: extractErrorMessage(from: data)
            )
        }

        guard let content = extractResponseContent(from: data) else {
            throw AIServiceError.invalidResponse
        }

        return content
    }

    private func requestURL() -> URL? {
        guard let baseURL = URL(string: configuration.baseURL) else {
            return nil
        }

        switch configuration.apiFormat {
        case .openAICompatible:
            return normalizedURL(
                from: baseURL,
                endpointPath: "/v1/chat/completions",
                parentPath: "/v1"
            )
        case .ollama:
            return normalizedURL(
                from: baseURL,
                endpointPath: "/api/chat",
                parentPath: "/api"
            )
        }
    }

    private func normalizedURL(from baseURL: URL, endpointPath: String, parentPath: String) -> URL {
        let currentPath = normalizedPath(baseURL.path)
        let normalizedEndpoint = normalizedPath(endpointPath)
        let normalizedParent = normalizedPath(parentPath)

        if currentPath == "/" {
            return baseURL.appending(path: normalizedEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }
        if currentPath.hasSuffix(normalizedEndpoint) {
            return baseURL
        }
        if currentPath.hasSuffix(normalizedParent) {
            let suffix = normalizedEndpoint.replacingOccurrences(of: normalizedParent, with: "")
            return baseURL.appending(path: suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        return baseURL
    }

    private func normalizedPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmedPath.isEmpty ? "/" : "/" + trimmedPath
    }

    private func requestBody(messages: [Message]) -> [String: Any] {
        let encodedMessages = messages.map { message in
            [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }

        switch configuration.apiFormat {
        case .openAICompatible:
            return [
                "model": configuration.model,
                "messages": encodedMessages
            ]
        case .ollama:
            return [
                "model": configuration.model,
                "stream": false,
                "messages": encodedMessages
            ]
        }
    }

    private func extractResponseContent(from data: Data) -> String? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }

        switch configuration.apiFormat {
        case .openAICompatible:
            let choices = json["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            if let content = message?["content"] as? String {
                return content
            }
            if let contentParts = message?["content"] as? [[String: Any]] {
                let textParts = contentParts.compactMap { $0["text"] as? String }
                return textParts.isEmpty ? nil : textParts.joined(separator: "\n")
            }
            return nil
        case .ollama:
            let message = json["message"] as? [String: Any]
            return message?["content"] as? String
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        if let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            if let error = json["error"] as? String {
                return error
            }
            if let message = json["message"] as? String {
                return message
            }
        }

        let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let body, !body.isEmpty {
            return body
        }
        return nil
    }

    private func normalizeJSONObject(in content: String) -> String? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            return nil
        }

        if let fencedJSON = extractFencedJSON(from: trimmedContent) {
            return fencedJSON
        }

        return extractFirstJSONObject(from: trimmedContent)
    }

    private func extractFencedJSON(from content: String) -> String? {
        guard let openingFence = content.range(of: "```") else {
            return nil
        }

        let bodyStart = openingFence.upperBound
        guard let closingFence = content[bodyStart...].range(of: "```") else {
            return nil
        }

        var fencedBody = String(content[bodyStart..<closingFence.lowerBound])
        let trimmedLeadingWhitespace = fencedBody.drop(while: \.isWhitespace)
        if trimmedLeadingWhitespace.lowercased().hasPrefix("json") {
            fencedBody = String(trimmedLeadingWhitespace.dropFirst(4))
        }

        return extractFirstJSONObject(from: fencedBody.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func extractFirstJSONObject(from content: String) -> String? {
        guard let startIndex = content.firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var isInsideString = false
        var isEscaped = false

        for index in content[startIndex...].indices {
            let character = content[index]

            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                continue
            }

            if character == "\"" {
                isInsideString = true
                continue
            }

            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(content[startIndex...index])
                }
            }
        }

        return nil
    }
}

struct AIResponse: Decodable {
    let narration: String
}
