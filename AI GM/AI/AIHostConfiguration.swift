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

enum AIProviderPreset: String, CaseIterable, Identifiable {
    case openAI
    case deepSeek
    case groq
    case openRouter
    case ollama
    case lmStudio
    case customOpenAICompatible
    case customOllama

    var id: String {
        rawValue
    }

    var provider: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .deepSeek:
            return "DeepSeek"
        case .groq:
            return "Groq"
        case .openRouter:
            return "OpenRouter"
        case .ollama:
            return "Ollama"
        case .lmStudio:
            return "LM Studio"
        case .customOpenAICompatible:
            return "自訂 OpenAI-compatible"
        case .customOllama:
            return "自訂 Ollama"
        }
    }

    var apiFormat: AIAPIFormat {
        switch self {
        case .ollama, .customOllama:
            return .ollama
        default:
            return .openAICompatible
        }
    }

    var baseURL: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .deepSeek:
            return "https://api.deepseek.com/v1"
        case .groq:
            return "https://api.groq.com/openai/v1"
        case .openRouter:
            return "https://openrouter.ai/api/v1"
        case .ollama, .customOllama:
            return "http://localhost:11434"
        case .lmStudio:
            return "http://localhost:1234/v1"
        case .customOpenAICompatible:
            return "https://example.com/v1"
        }
    }

    var model: String {
        switch self {
        case .openAI:
            return "gpt-4o-mini"
        case .deepSeek:
            return "deepseek-chat"
        case .groq:
            return "llama-3.3-70b-versatile"
        case .openRouter:
            return "openai/gpt-4o-mini"
        case .ollama, .customOllama:
            return "llama3.1"
        case .lmStudio:
            return "local-model"
        case .customOpenAICompatible:
            return "custom-model"
        }
    }

    var description: String {
        switch self {
        case .openAI:
            return "官方 OpenAI 端點，適合直接用標準雲端模型。"
        case .deepSeek:
            return "DeepSeek 官方端點，走 OpenAI-compatible 格式。"
        case .groq:
            return "Groq 官方端點，適合低延遲推理。"
        case .openRouter:
            return "OpenRouter 聚合端點，可切多家模型。"
        case .ollama:
            return "本機或區網上的 Ollama 服務。"
        case .lmStudio:
            return "LM Studio 的本機 OpenAI-compatible server。"
        case .customOpenAICompatible:
            return "自架或第三方 OpenAI-compatible 服務。"
        case .customOllama:
            return "自訂 Ollama 位址，適合遠端或區網主機。"
        }
    }

    /// 雲端服務一定要 API Key；本機與自訂服務不一定需要，交給使用者決定
    var requiresAPIKey: Bool {
        switch self {
        case .openAI, .deepSeek, .groq, .openRouter:
            return true
        case .ollama, .lmStudio, .customOpenAICompatible, .customOllama:
            return false
        }
    }

    func apply(to configuration: AIHostConfiguration) -> AIHostConfiguration {
        AIHostConfiguration(
            provider: provider,
            apiFormat: apiFormat,
            baseURL: baseURL,
            model: model,
            apiKey: configuration.apiKey,
            systemPrompt: configuration.systemPrompt
        )
    }

    static func inferred(from configuration: AIHostConfiguration) -> AIProviderPreset {
        let canonicalConfiguration = configuration.canonicalized()

        if let providerMatch = AIProviderPreset.allCases.first(where: {
            $0.provider == canonicalConfiguration.provider &&
            $0.apiFormat == canonicalConfiguration.apiFormat
        }) {
            return providerMatch
        }

        switch canonicalConfiguration.apiFormat {
        case .openAICompatible:
            return .customOpenAICompatible
        case .ollama:
            return .customOllama
        }
    }
}

struct AIHostConfiguration: Codable, Equatable {
    var provider: String
    var apiFormat: AIAPIFormat
    var baseURL: String
    var model: String
    var apiKey: String
    var systemPrompt: String

    enum CodingKeys: String, CodingKey {
        case provider, apiFormat, baseURL, model, systemPrompt
    }

    init(
        provider: String,
        apiFormat: AIAPIFormat,
        baseURL: String,
        model: String,
        apiKey: String,
        systemPrompt: String
    ) {
        self.provider = provider
        self.apiFormat = apiFormat
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.systemPrompt = systemPrompt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(String.self, forKey: .provider)
        apiFormat = try container.decode(AIAPIFormat.self, forKey: .apiFormat)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        model = try container.decode(String.self, forKey: .model)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        apiKey = ""
    }

    enum ValidationError: LocalizedError, Equatable {
        case emptyProvider
        case emptyModel
        case emptyBaseURL
        case invalidBaseURL
        case missingAPIKey(provider: String)

        var errorDescription: String? {
            switch self {
            case .emptyProvider:
                return "AI 供應商不能空白。"
            case .emptyModel:
                return "Model 不能空白。"
            case .emptyBaseURL:
                return "Base URL 不能空白。"
            case .invalidBaseURL:
                return "Base URL 格式不正確，需要以 http:// 或 https:// 開頭。"
            case .missingAPIKey(let provider):
                return "\(provider) 需要 API Key，請在 AI 設定填入。"
            }
        }
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

    /// 建立房間或更新房間設定時用：雲端供應商還要有 API Key，免得等到開始遊戲才失敗。
    /// 讀取已存的設定時不檢查，沒填 Key 的人才打得開設定補上
    func validatedForHosting() throws -> AIHostConfiguration {
        let configuration = try validated()

        if configuration.apiKey.isEmpty && AIProviderPreset.inferred(from: configuration).requiresAPIKey {
            throw ValidationError.missingAPIKey(provider: configuration.provider)
        }

        return configuration
    }
}

struct AISettingsSummary: Equatable {
    let title: String
    let subtitle: String
    let badges: [String]

    init(provider: String, model: String, apiFormat: AIAPIFormat) {
        let trimmedProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatBadge = apiFormat.summaryLabel

        title = trimmedProvider.isEmpty ? "AI 未設定" : trimmedProvider
        subtitle = trimmedModel.isEmpty ? "Model 未設定" : trimmedModel
        badges = title == formatBadge ? [title] : [title, formatBadge]
    }
}

struct AISettingsDraft: Equatable {
    var providerPreset: AIProviderPreset
    var apiFormat: AIAPIFormat
    var baseURL: String
    var model: String
    var apiKey: String
    var systemPrompt: String

    var configuration: AIHostConfiguration {
        AIHostConfiguration(
            provider: providerPreset.provider,
            apiFormat: apiFormat,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            systemPrompt: systemPrompt
        )
    }

    init(
        providerPreset: AIProviderPreset,
        apiFormat: AIAPIFormat,
        baseURL: String,
        model: String,
        apiKey: String,
        systemPrompt: String
    ) {
        self.providerPreset = providerPreset
        self.apiFormat = apiFormat
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.systemPrompt = systemPrompt
    }

    init(configuration: AIHostConfiguration, providerPreset: AIProviderPreset) {
        self.init(
            providerPreset: providerPreset,
            apiFormat: configuration.apiFormat,
            baseURL: configuration.baseURL,
            model: configuration.model,
            apiKey: configuration.apiKey,
            systemPrompt: configuration.systemPrompt
        )
    }

    mutating func applyPreset(_ preset: AIProviderPreset) {
        let updated = preset.apply(to: configuration)
        providerPreset = preset
        apiFormat = updated.apiFormat
        baseURL = updated.baseURL
        model = updated.model
        apiKey = updated.apiKey
        systemPrompt = updated.systemPrompt
    }

}

extension AIAPIFormat {
    var summaryLabel: String {
        switch self {
        case .openAICompatible:
            return "OpenAI"
        case .ollama:
            return "Ollama"
        }
    }
}

enum AIHostConfigurationStore {
    /// 設定與 API Key 存放的位置；測試改用獨立的 UserDefaults suite 與 Keychain service，
    /// 才不會清掉 App 真正的設定
    struct Storage {
        let defaults: UserDefaults
        let keychainService: String

        static let app = Storage(defaults: .standard, keychainService: KeychainService.defaultService)
    }

    private static let lastUsedKey = "hostAIConfig.lastUsed"
    private static let apiKeyPrefix = "aiApiKey."

    private static func configKey(campaignId: String) -> String {
        "hostAIConfig.\(campaignId)"
    }

    private static func apiKeyKey(campaignId: String) -> String {
        "\(apiKeyPrefix)\(campaignId)"
    }

    private static let lastUsedApiKeyKey = "\(apiKeyPrefix)lastUsed"

    /// 有存設定的房間，最近用過的在前
    private static let recentCampaignIdsKey = "hostAIConfigRecentCampaignIds"

    /// 只留最近幾個房間的設定，不然每建一個房間 Keychain 就多一份 API Key
    static let maxStoredCampaigns = 10

    static func save(_ configuration: AIHostConfiguration, campaignId: String, storage: Storage = .app) throws {
        try save(configuration, configKey: configKey(campaignId: campaignId), apiKeyKey: apiKeyKey(campaignId: campaignId), storage: storage)
        markRecentlyUsed(campaignId: campaignId, storage: storage)
    }

    static func load(campaignId: String, storage: Storage = .app) throws -> AIHostConfiguration? {
        let configuration = try load(configKey: configKey(campaignId: campaignId), apiKeyKey: apiKeyKey(campaignId: campaignId), storage: storage)
        if configuration != nil {
            markRecentlyUsed(campaignId: campaignId, storage: storage)
        }
        return configuration
    }

    static func saveLastUsed(_ configuration: AIHostConfiguration, storage: Storage = .app) throws {
        try save(configuration, configKey: lastUsedKey, apiKeyKey: lastUsedApiKeyKey, storage: storage)
    }

    static func loadLastUsed(storage: Storage = .app) throws -> AIHostConfiguration? {
        try load(configKey: lastUsedKey, apiKeyKey: lastUsedApiKeyKey, storage: storage)
    }

    static func clearLastUsed(storage: Storage = .app) {
        storage.defaults.removeObject(forKey: lastUsedKey)
        KeychainService.delete(key: lastUsedApiKeyKey, service: storage.keychainService)
    }

    static func clear(campaignId: String, storage: Storage = .app) {
        removeConfiguration(campaignId: campaignId, storage: storage)
        let remaining = storedCampaignIds(storage: storage).filter { $0 != campaignId }
        storage.defaults.set(remaining, forKey: recentCampaignIdsKey)
    }

    private static func removeConfiguration(campaignId: String, storage: Storage) {
        storage.defaults.removeObject(forKey: configKey(campaignId: campaignId))
        KeychainService.delete(key: apiKeyKey(campaignId: campaignId), service: storage.keychainService)
    }

    /// 把房間排到最前面，超出上限的舊房間連同 API Key 一起刪掉
    private static func markRecentlyUsed(campaignId: String, storage: Storage) {
        var campaignIds = storedCampaignIds(storage: storage).filter { $0 != campaignId }
        campaignIds.insert(campaignId, at: 0)

        for staleCampaignId in campaignIds.dropFirst(maxStoredCampaigns) {
            removeConfiguration(campaignId: staleCampaignId, storage: storage)
        }
        storage.defaults.set(Array(campaignIds.prefix(maxStoredCampaigns)), forKey: recentCampaignIdsKey)
    }

    /// 有這份清單之前存的房間 API Key 不知道先後，排在最後面，超過上限時先清掉
    private static func storedCampaignIds(storage: Storage) -> [String] {
        let recorded = storage.defaults.stringArray(forKey: recentCampaignIdsKey) ?? []
        let legacy = KeychainService.allKeys(service: storage.keychainService)
            .filter { $0.hasPrefix(apiKeyPrefix) && $0 != lastUsedApiKeyKey }
            .map { String($0.dropFirst(apiKeyPrefix.count)) }
            .filter { !recorded.contains($0) }
            .sorted()
        return recorded + legacy
    }

    private static func save(_ configuration: AIHostConfiguration, configKey: String, apiKeyKey: String, storage: Storage) throws {
        let canonicalConfiguration = try configuration.validated()

        let encoder = JSONEncoder()
        let data = try encoder.encode(canonicalConfiguration)
        storage.defaults.set(data, forKey: configKey)

        let trimmedApiKey = canonicalConfiguration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedApiKey.isEmpty {
            try KeychainService.save(key: apiKeyKey, value: trimmedApiKey, service: storage.keychainService)
        } else {
            KeychainService.delete(key: apiKeyKey, service: storage.keychainService)
        }
    }

    private static func load(configKey: String, apiKeyKey: String, storage: Storage) throws -> AIHostConfiguration? {
        guard let data = storage.defaults.data(forKey: configKey) else {
            return nil
        }

        var decoded = try JSONDecoder().decode(AIHostConfiguration.self, from: data)

        // Migration: if old format still has apiKey embedded in JSON, extract it
        if decoded.apiKey.isEmpty, let legacyApiKey = extractLegacyApiKey(from: data) {
            decoded.apiKey = legacyApiKey
            // Re-save to migrate: config without apiKey + apiKey in Keychain.
            // `try?` is intentional: if migration re-save fails (e.g. Keychain busy),
            // we still return the decoded config with apiKey intact. The next load
            // will attempt migration again — a benign retry with no data loss.
            try? save(decoded, configKey: configKey, apiKeyKey: apiKeyKey, storage: storage)
        } else {
            decoded.apiKey = KeychainService.load(key: apiKeyKey, service: storage.keychainService) ?? ""
        }

        return try decoded.validated()
    }

    private static func extractLegacyApiKey(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiKey = json["apiKey"] as? String,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
