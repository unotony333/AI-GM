//
//  AIHostConfiguration.swift
//  AI GM
//
//  Created by tony on 2026/3/31.
//

import Foundation

enum AIAPIFormat: String, CaseIterable, Codable, Identifiable {
    case openAICompatible
    case ollama

    var id: String {
        rawValue
    }
}

struct AIHostConfiguration: Codable, Equatable {
    var provider: String
    var apiFormat: AIAPIFormat
    var baseURL: String
    var model: String
    var apiKey: String
    var systemPrompt: String

    enum ValidationError: Error, Equatable {
        case emptyProvider
        case emptyModel
        case emptyBaseURL
        case invalidBaseURL
    }

    var trimmedProvider: String {
        provider.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func canonicalized() -> AIHostConfiguration {
        AIHostConfiguration(
            provider: trimmedProvider,
            apiFormat: apiFormat,
            baseURL: trimmedBaseURL,
            model: trimmedModel,
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            systemPrompt: systemPrompt
        )
    }

    func validated() throws -> AIHostConfiguration {
        let configuration = canonicalized()

        guard !configuration.provider.isEmpty else {
            throw ValidationError.emptyProvider
        }
        guard !configuration.model.isEmpty else {
            throw ValidationError.emptyModel
        }
        guard !configuration.baseURL.isEmpty else {
            throw ValidationError.emptyBaseURL
        }
        guard let url = URL(string: configuration.baseURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            throw ValidationError.invalidBaseURL
        }

        return configuration
    }
}

enum AIHostConfigurationStore {
    private static let defaults = UserDefaults.standard

    private static func key(campaignId: String) -> String {
        "hostAIConfig.\(campaignId)"
    }

    static func save(_ configuration: AIHostConfiguration, campaignId: String) throws {
        let canonicalConfiguration = try configuration.validated()
        let encoder = JSONEncoder()
        let data = try encoder.encode(canonicalConfiguration)
        defaults.set(data, forKey: key(campaignId: campaignId))
    }

    static func load(campaignId: String) throws -> AIHostConfiguration? {
        guard let data = defaults.data(forKey: key(campaignId: campaignId)) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(AIHostConfiguration.self, from: data)
        return try decoded.validated()
    }
}
