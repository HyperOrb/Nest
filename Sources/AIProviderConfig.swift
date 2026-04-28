import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case gemini
    case openRouter
    case openAICompatible
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .openRouter: return "OpenRouter"
        case .openAICompatible: return "OpenAI-compatible"
        case .ollama: return "Ollama Local"
        }
    }

    var defaultModel: String {
        switch self {
        case .gemini: return "gemini-2.0-flash"
        case .openRouter: return "openai/gpt-oss-20b:free"
        case .openAICompatible: return "gpt-4o-mini"
        case .ollama: return "llava"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .openAICompatible: return "https://api.openai.com/v1"
        case .ollama: return "http://localhost:11434"
        }
    }

    var requiresAPIKey: Bool {
        self != .ollama
    }
}

struct AIProviderConfig {
    var provider: AIProvider
    var apiKey: String
    var model: String
    var baseURL: String

    static let configPath = NSString(string: "~/.finder_ai_config.json").expandingTildeInPath

    static var `default`: AIProviderConfig {
        AIProviderConfig(
            provider: .gemini,
            apiKey: "",
            model: AIProvider.gemini.defaultModel,
            baseURL: AIProvider.gemini.defaultBaseURL
        )
    }

    static func load() -> AIProviderConfig {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return legacyEnvironmentConfig()
        }

        let provider = AIProvider(rawValue: json["AI_PROVIDER"] as? String ?? "") ?? .gemini
        return load(provider: provider, from: json)
    }

    static func loadAll() -> [AIProvider: AIProviderConfig] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [.gemini: legacyEnvironmentConfig()]
        }

        var configs: [AIProvider: AIProviderConfig] = [:]
        for provider in AIProvider.allCases {
            configs[provider] = load(provider: provider, from: json)
        }
        return configs
    }

    static func saveAll(activeProvider: AIProvider, configs: [AIProvider: AIProviderConfig]) {
        var providers: [String: [String: String]] = [:]
        for provider in AIProvider.allCases {
            let config = configs[provider] ?? AIProviderConfig(
                provider: provider,
                apiKey: "",
                model: provider.defaultModel,
                baseURL: provider.defaultBaseURL
            )
            providers[provider.rawValue] = [
                "apiKey": cleanAPIKey(config.apiKey, provider: provider),
                "model": config.model.trimmingCharacters(in: .whitespacesAndNewlines),
                "baseURL": config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            ]
        }

        let config: [String: Any] = [
            "AI_PROVIDER": activeProvider.rawValue,
            "providers": providers
        ]

        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            try? data.write(to: URL(fileURLWithPath: Self.configPath))
        }
    }

    private static func load(provider: AIProvider, from json: [String: Any]) -> AIProviderConfig {
        let providerConfigs = json["providers"] as? [String: [String: String]]
        let stored = providerConfigs?[provider.rawValue]

        let legacyAPIKey = stored?["apiKey"] ??
            ((AIProvider(rawValue: json["AI_PROVIDER"] as? String ?? "") ?? .gemini) == provider ? json["AI_API_KEY"] as? String : nil) ??
            (provider == .gemini ? json["GOOGLE_API_KEY"] as? String : nil) ??
            ""
        let rawAPIKey = legacyAPIKey
        let model = stored?["model"] ??
            ((AIProvider(rawValue: json["AI_PROVIDER"] as? String ?? "") ?? .gemini) == provider ? json["AI_MODEL"] as? String : nil) ??
            provider.defaultModel
        let baseURL = stored?["baseURL"] ??
            ((AIProvider(rawValue: json["AI_PROVIDER"] as? String ?? "") ?? .gemini) == provider ? json["AI_BASE_URL"] as? String : nil) ??
            provider.defaultBaseURL

        return AIProviderConfig(provider: provider, apiKey: cleanAPIKey(rawAPIKey, provider: provider), model: model, baseURL: baseURL)
    }

    func save() {
        var configs = Self.loadAll()
        configs[provider] = self
        Self.saveAll(activeProvider: provider, configs: configs)
    }

    private static func legacyEnvironmentConfig() -> AIProviderConfig {
        var config = AIProviderConfig.default
        if let env = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] {
            config.apiKey = cleanAPIKey(env, provider: .gemini)
        }
        return config
    }

    static func cleanAPIKey(_ value: String, provider: AIProvider) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // If the user pastes into a non-empty field, keys can accidentally become
        // "AIza...AIza..." or "sk-...sk-...". Keep the first complete-looking key.
        let marker: String?
        switch provider {
        case .gemini:
            marker = "AIza"
        case .openRouter, .openAICompatible:
            marker = trimmed.hasPrefix("sk-") ? "sk-" : nil
        case .ollama:
            marker = nil
        }

        guard let marker else { return trimmed }
        let startOffset = min(marker.count, trimmed.count)
        let searchStart = trimmed.index(trimmed.startIndex, offsetBy: startOffset)
        guard let secondMarker = trimmed.range(of: marker, options: [], range: searchStart..<trimmed.endIndex) else {
            return trimmed
        }

        return String(trimmed[..<secondMarker.lowerBound])
    }
}
