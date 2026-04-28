import AppKit
import Foundation

class AIAgent {
    static let shared = AIAgent()

    private let commandPrompt = """
    You are a macOS Terminal command generator embedded in Finder.
    Act like a file agent: understand the user's intent, choose the safest local command, and convert it into one previewable shell command.

    Rules:
    - Output ONLY the shell command. No markdown fences, no explanations.
    - Use the exact file paths provided.
    - Prefer macOS built-in tools: sips, zip, unzip, open, mv, cp, file, mdls, mdfind, xattr, osascript, lp, caffeinate, system_profiler, bc.
    - For video/audio use ffmpeg/ffprobe when needed. If a command depends on an optional tool, include a preflight like: command -v ffmpeg >/dev/null || { echo 'Install ffmpeg to do this.'; exit 127; }
    - For document conversion use pandoc when needed, with the same preflight style.
    - For PDFs use qpdf, ghostscript, poppler tools like pdftotext/pdfunite/pdfseparate when needed, with preflight.
    - For advanced image operations use ImageMagick's magick command with preflight. Use it for contact sheets/grids, borders, crops, trims, text overlays, compositing, quality changes, and operations sips cannot do.
    - ImageMagick preflight example: command -v magick >/dev/null || { echo 'Install ImageMagick in Settings > Extra Tools, or run: brew install imagemagick'; exit 127; }
    - For calculations, output an exact local command using bc or a deterministic shell expression.
    - Output files should go in the same directory as the input, or in the current Finder folder when no files are selected.
    - Never use sudo. Never install software.
    - Never run brew install automatically. If a tool is missing, print the install hint and exit.
    - Prefer moving files to Trash via Finder over permanent deletion.
    """

    private let answerPrompt = """
    You are a helpful AI assistant living inside macOS Finder.
    Answer the user's question about selected Finder files or the current folder in clear natural language. This is the conversational side of Nest.

    Rules:
    - Be concise and useful.
    - If image data is provided, answer based on the image itself.
    - If only file metadata is available, reason from the filename, extension, path, size, and metadata, and clearly say when you cannot inspect contents.
    - Do not invent file contents you cannot see.
    - Do not output terminal commands.
    """

    static func shouldAnswerDirectly(_ prompt: String) -> Bool {
        let p = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if p.hasSuffix("?") { return true }

        let questionStarters = [
            "what is", "what's", "who is", "who made", "who wrote",
            "tell me", "describe", "explain", "summarize", "summarise",
            "is this", "does this", "can you identify", "identify this",
            "what kind", "what type"
        ]
        return questionStarters.contains { p.hasPrefix($0) }
    }

    func translate(prompt: String, files: [String], currentFolder: String? = nil) async throws -> String {
        let config = AIProviderConfig.load()
        let text = try await complete(
            systemPrompt: commandPrompt,
            userText: requestContext(prompt: prompt, files: files, currentFolder: currentFolder, label: "User command"),
            files: [],
            config: config,
            temperature: 0.1
        )

        var cmd = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cmd.hasPrefix("```") {
            let lines = cmd.components(separatedBy: "\n").dropFirst().dropLast()
            cmd = lines.joined(separator: "\n")
        }
        return cmd
    }

    func answer(prompt: String, files: [String], currentFolder: String? = nil) async throws -> String {
        let config = AIProviderConfig.load()
        return try await complete(
            systemPrompt: answerPrompt,
            userText: requestContext(prompt: prompt, files: files, currentFolder: currentFolder, label: "User question"),
            files: files,
            config: config,
            temperature: 0.2
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func test(config: AIProviderConfig) async throws -> String {
        let response = try await complete(
            systemPrompt: "Reply with a short confirmation that the provider is working.",
            userText: "Say: Nest provider check OK.",
            files: [],
            config: config,
            temperature: 0
        )
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func complete(systemPrompt: String, userText: String, files: [String], config: AIProviderConfig, temperature: Double) async throws -> String {
        switch config.provider {
        case .gemini:
            return try await completeGemini(systemPrompt: systemPrompt, userText: userText, files: files, config: config, temperature: temperature)
        case .openRouter, .openAICompatible:
            return try await completeOpenAICompatible(systemPrompt: systemPrompt, userText: userText, files: files, config: config, temperature: temperature)
        case .ollama:
            return try await completeOllama(systemPrompt: systemPrompt, userText: userText, files: files, config: config, temperature: temperature)
        }
    }

    private func completeGemini(systemPrompt: String, userText: String, files: [String], config: AIProviderConfig, temperature: Double) async throws -> String {
        guard !config.apiKey.isEmpty else { throw AgentError.noApiKey(config.provider.displayName) }

        let base = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(string: "\(base)/models/\(config.model):generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: config.apiKey)]
        let url = components.url!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var parts: [[String: Any]] = [["text": userText]]
        for file in files.prefix(2) {
            if let imagePart = geminiImagePart(for: file) {
                parts.append(imagePart)
            }
        }

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["parts": parts]],
            "generationConfig": ["temperature": temperature, "maxOutputTokens": 512]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AgentError.apiError(config.provider.displayName, Self.apiErrorMessage(from: data))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw AgentError.parseError(config.provider.displayName)
        }
        return text
    }

    private func completeOpenAICompatible(systemPrompt: String, userText: String, files: [String], config: AIProviderConfig, temperature: Double) async throws -> String {
        guard !config.apiKey.isEmpty else { throw AgentError.noApiKey(config.provider.displayName) }

        let models = openAICompatibleModels(for: config, files: files)
        var lastError: Error?
        for model in models {
            do {
                return try await completeOpenAICompatible(
                    systemPrompt: systemPrompt,
                    userText: userText,
                    files: files,
                    config: config,
                    model: model,
                    temperature: temperature
                )
            } catch {
                lastError = error
                if !shouldTryFallback(after: error, provider: config.provider) {
                    throw error
                }
            }
        }

        throw lastError ?? AgentError.parseError(config.provider.displayName)
    }

    private func completeOpenAICompatible(systemPrompt: String, userText: String, files: [String], config: AIProviderConfig, model: String, temperature: Double) async throws -> String {
        let base = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = URL(string: "\(base)/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        if config.provider == .openRouter {
            req.setValue("Nest", forHTTPHeaderField: "X-Title")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": openAIUserContent(text: userText, files: files)]
            ],
            "temperature": temperature,
            "max_tokens": 512
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AgentError.apiError(config.provider.displayName, Self.apiErrorMessage(from: data))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AgentError.parseError(config.provider.displayName)
        }
        return text
    }

    private func openAICompatibleModels(for config: AIProviderConfig, files: [String]) -> [String] {
        guard config.provider == .openRouter else { return [config.model] }

        let visionModels = [
            config.model,
            "google/gemma-4-26b-a4b-it:free",
            "nvidia/nemotron-nano-12b-v2-vl:free",
            "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
            "baidu/qianfan-ocr-fast:free"
        ]

        let textModels = [
            config.model,
            "openai/gpt-oss-20b:free",
            "qwen/qwen3-next-80b-a3b-instruct:free",
            "google/gemma-4-26b-a4b-it:free",
            "liquid/lfm-2.5-1.2b-instruct:free"
        ]

        let fallbackModels = files.contains(where: { imageMimeType(for: $0) != nil }) ? visionModels + textModels : textModels

        return Array(NSOrderedSet(array: fallbackModels)) as? [String] ?? fallbackModels
    }

    private func shouldTryFallback(after error: Error, provider: AIProvider) -> Bool {
        guard provider == .openRouter else { return false }
        guard let agentError = error as? AgentError else { return false }

        switch agentError {
        case .apiError(_, let message):
            let lower = message.lowercased()
            return lower.contains("no endpoints found") ||
                lower.contains("temporarily rate-limited") ||
                lower.contains("rate limit") ||
                lower.contains("provider returned error")
        default:
            return false
        }
    }

    private func completeOllama(systemPrompt: String, userText: String, files: [String], config: AIProviderConfig, temperature: Double) async throws -> String {
        let base = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = URL(string: "\(base)/api/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": config.model,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userText, "images": ollamaImages(files: files)]
            ],
            "options": ["temperature": temperature]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AgentError.apiError(config.provider.displayName, Self.apiErrorMessage(from: data))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AgentError.parseError(config.provider.displayName)
        }
        return text
    }

    private func requestContext(prompt: String, files: [String], currentFolder: String?, label: String) -> String {
        let folder = currentFolder ?? "unavailable"
        let fileLines = files.isEmpty
            ? "No files selected."
            : files.map { "- \(fileMetadata(for: $0))" }.joined(separator: "\n")

        return """
        Current Finder folder: \(folder)
        Selected files:
        \(fileLines)

        \(label): \(prompt)
        """
    }

    private func fileMetadata(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let attrs = (try? FileManager.default.attributesOfItem(atPath: path)) ?? [:]
        let size = attrs[.size].map { "\($0) bytes" } ?? "unknown size"
        return "\(url.lastPathComponent) | path: \(path) | extension: \(url.pathExtension) | size: \(size)"
    }

    private func openAIUserContent(text: String, files: [String]) -> Any {
        var content: [[String: Any]] = [["type": "text", "text": text]]
        for file in files.prefix(2) {
            if let dataURL = imageDataURL(for: file) {
                content.append(["type": "image_url", "image_url": ["url": dataURL]])
            }
        }
        return content.count == 1 ? text : content
    }

    private func geminiImagePart(for path: String) -> [String: Any]? {
        guard let mimeType = imageMimeType(for: path), let data = smallFileData(path) else { return nil }
        return ["inline_data": ["mime_type": mimeType, "data": data.base64EncodedString()]]
    }

    private func imageDataURL(for path: String) -> String? {
        guard imageMimeType(for: path) != nil else { return nil }

        if let jpegData = jpegData(for: path) {
            return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
        }

        guard let mimeType = imageMimeType(for: path), let data = smallFileData(path) else { return nil }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private func ollamaImages(files: [String]) -> [String] {
        files.prefix(2).compactMap { file in
            guard imageMimeType(for: file) != nil, let data = smallFileData(file) else { return nil }
            return data.base64EncodedString()
        }
    }

    private func smallFileData(_ path: String) -> Data? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? NSNumber,
              size.intValue <= 8_000_000 else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    private func jpegData(for path: String) -> Data? {
        guard let image = NSImage(contentsOfFile: path),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }

    private func imageMimeType(for path: String) -> String? {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "heif": return "image/heif"
        default: return nil
        }
    }

    private static func apiErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                let metadata = error["metadata"] as? [String: Any]
                let raw = metadata?["raw"] as? String
                let code = error["code"] as? String
                let type = error["type"] as? String
                return [code, type, raw ?? message]
                    .compactMap { $0 }
                    .joined(separator: " | ")
            }
            if let error = json["error"] as? String {
                return error
            }
        }
        return String(data: data, encoding: .utf8) ?? "Unknown API error"
    }
}

enum AgentError: LocalizedError {
    case noApiKey(String)
    case apiError(String, String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noApiKey(let provider):
            return "No \(provider) API key. Open Settings to add one."
        case .apiError(let provider, let msg):
            if msg.localizedCaseInsensitiveContains("incorrect api key") || msg.localizedCaseInsensitiveContains("invalid api key") {
                return "\(provider) rejected the API key. Check Settings."
            }
            if msg.localizedCaseInsensitiveContains("api key") || msg.localizedCaseInsensitiveContains("unauthorized") {
                return "\(provider) API key issue. Check Settings."
            }
            if msg.localizedCaseInsensitiveContains("insufficient_quota") {
                return "\(provider) has no usable API billing credits."
            }
            if msg.localizedCaseInsensitiveContains("rate_limit") || msg.localizedCaseInsensitiveContains("rate limit") {
                return "\(provider) rate limit hit. Try again shortly."
            }
            if msg.localizedCaseInsensitiveContains("quota") {
                return "\(provider) quota hit. Check provider billing."
            }
            if msg.localizedCaseInsensitiveContains("connection refused") {
                return "\(provider) is not reachable."
            }
            return "\(provider) error: \(msg.prefix(90))"
        case .parseError(let provider):
            return "Could not parse \(provider)'s response."
        }
    }
}
