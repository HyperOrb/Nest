import Foundation

struct CommandNarrator {
    static func preview(for command: String) -> String {
        let c = command.lowercased()

        if c.contains(" to trash") {
            return "I will move the selected item to the Trash."
        }
        if c.hasPrefix("zip ") || c.contains(" zip ") {
            return "I will create a zip archive from the selected file or folder."
        }
        if c.contains("sips ") && c.contains("-compressed.jpg") {
            return "I will make a smaller JPEG copy next to the original."
        }
        if c.contains("sips ") && c.contains("format jpeg") {
            return "I will convert the selected image to JPEG."
        }
        if c.contains("sips ") && c.contains("format png") {
            return "I will convert the selected image to PNG."
        }
        if c.hasPrefix("touch ") {
            return "I will create a new empty file in this Finder folder."
        }
        if c.hasPrefix("mkdir ") {
            return "I will create a new folder here."
        }
        if c.hasPrefix("open ") {
            return "I will open the selected item."
        }
        if c.hasPrefix("wc ") {
            return "I will count the words and show the result."
        }
        if c.hasPrefix("md5 ") {
            return "I will calculate the MD5 checksum."
        }
        if c.contains("file -b") && c.contains("mdls ") {
            return "I will inspect the selected file and tell you what kind of file it is."
        }
        if c.contains("sips -g pixelwidth") {
            return "I will read the image dimensions."
        }
        if c.contains("kmditemauthors") || c.contains("kmditemcreator") {
            return "I will look for author metadata on the selected file."
        }

        return "I translated your request into a local command. Review it before running."
    }

    static func success(for command: String, output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = command.lowercased()

        if c.contains(" to trash") {
            return "Moved to Trash."
        }
        if c.hasPrefix("zip ") || c.contains(" zip ") {
            return "Created the zip archive."
        }
        if c.contains("sips ") && c.contains("-compressed.jpg") {
            return "Created a compressed JPEG copy."
        }
        if c.contains("sips ") && c.contains("format jpeg") {
            return "Converted to JPEG."
        }
        if c.contains("sips ") && c.contains("format png") {
            return "Converted to PNG."
        }
        if c.hasPrefix("touch ") {
            return "Created the new file."
        }
        if c.hasPrefix("mkdir ") {
            return "Created the folder."
        }
        if c.contains("file -b") && c.contains("mdls ") {
            return readableInspection(from: trimmed)
        }
        if c.contains("sips -g pixelwidth") {
            return readableDimensions(from: trimmed)
        }
        if c.contains("kmditemauthors") || c.contains("kmditemcreator") {
            return readableMetadata(from: trimmed, fallback: "I could not find author metadata.")
        }
        if !trimmed.isEmpty {
            return "Done: \(trimmed.prefix(70))"
        }
        return "Done."
    }

    static func failure(for command: String, output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "I could not finish that command."
        }
        return "I could not finish: \(trimmed.prefix(80))"
    }

    private static func readableInspection(from output: String) -> String {
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let fileLine = lines.first(where: { $0.hasPrefix("File: ") }) else {
            return "I inspected it: \(output.prefix(90))"
        }

        let fileName = URL(fileURLWithPath: String(fileLine.dropFirst(6))).lastPathComponent
        let kind = lines.first(where: { !$0.hasPrefix("File: ") && !$0.hasPrefix("kMDItem") }) ?? "file"
        return "\(fileName) is \(kind.prefix(80))."
    }

    private static func readableDimensions(from output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        let width = metadataValue(named: "pixelWidth", in: lines)
        let height = metadataValue(named: "pixelHeight", in: lines)
        if let width, let height {
            return "The image is \(width) x \(height) pixels."
        }
        return "I read the dimensions: \(output.prefix(80))"
    }

    private static func readableMetadata(from output: String, fallback: String) -> String {
        let unavailable = ["(null)", "null", ""]
        let values = output
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                guard let value = line.components(separatedBy: "=").last else { return nil }
                let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return unavailable.contains(cleaned.lowercased()) ? nil : cleaned
            }

        guard !values.isEmpty else { return fallback }
        return "I found this metadata: \(values.joined(separator: ", ").prefix(90))"
    }

    private static func metadataValue(named name: String, in lines: [String]) -> String? {
        lines.first(where: { $0.contains(name) })?
            .components(separatedBy: ":")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
