//
//  AIService.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

class AIService {

    private let apiKey = "YOUR_API_KEY"

    func sendMessage(prompt: String) async throws -> AIResponse {
        let content = try await sendRawJSON(prompt: prompt)
        guard let data = content.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }
        return try JSONDecoder().decode(AIResponse.self, from: data)
    }

    enum AIServiceError: Error {
        case invalidResponse
        case invalidURL
    }

    func sendRawJSON(prompt: String) async throws -> String {
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "只輸出JSON"],
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]

        return message?["content"] as? String ?? "{}"
    }
}

struct AIResponse: Decodable {
    let narration: String
}
