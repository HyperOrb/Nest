import Foundation

struct InstantActions {
    static func resolveQuickShortcut(keyword: String, files: [String], currentFolder: String? = nil) -> String? {
        let k = normalized(keyword)
        guard shouldRunLocally(keyword: k) else { return nil }
        return resolve(keyword: k, files: files, currentFolder: currentFolder)
    }

    static func quickShortcutNeedsFiles(keyword: String) -> Bool {
        let k = normalized(keyword)
        let fileShortcuts = ["zip", "unzip", "jpg", "jpeg", "png", "webp", "heic", "mp4", "wav", "trash", "delete", "open", "wc", "word count", "md5"]
        return fileShortcuts.contains(k)
    }

    private static func shouldRunLocally(keyword: String) -> Bool {
        let k = normalized(keyword)
        let exactShortcuts = [
            "zip", "unzip", "jpg", "jpeg", "png", "webp", "heic", "mp4", "wav",
            "trash", "delete", "open", "wc", "word count", "md5", "pwd",
            "show hidden", "show hidden files", "hide hidden", "hide hidden files",
            "toggle dark mode"
        ]

        if exactShortcuts.contains(k) { return true }
        return k.range(of: #"^\s*[\d\.\s\+\-\*/\(\)%]+\s*$"#, options: .regularExpression) != nil
    }

    static func needsFiles(keyword: String) -> Bool {
        let k = normalized(keyword)
        let fileActionWords = [
            "zip", "archive", "compress", "unzip", "extract", "decompress",
            "jpg", "jpeg", "png", "webp", "heic", "mp4", "wav", "gif", "bitrate",
            "rotate", "resize", "crop", "border", "grid", "contact sheet", "overlay", "text", "trim", "transparent", "pdf", "docx", "markdown",
            "html", "epub", "delete", "remove", "trash", "print",
            "open", "md5", "word count", "copy path", "what is", "what's",
            "what type", "kind of file", "file type", "info", "metadata",
            "dimensions", "size", "author", "downloaded", "greyed", "gray"
        ]
        return fileActionWords.contains { k.contains($0) }
    }

    static func resolve(keyword: String, files: [String], currentFolder: String? = nil) -> String? {
        let k = normalized(keyword)
        guard !files.isEmpty else {
            if let folder = currentFolder, let command = folderAction(keyword: k, folder: folder) {
                return command
            }

            // Calculation
            if k.contains("+") || k.contains("*") || k.contains("/") || k.contains("-") {
                return "echo \"\(k)\" | bc -l"
            }
            return nil
        }
        let quoted = files.map(shellQuote).joined(separator: " ")
        let dir = URL(fileURLWithPath: files[0]).deletingLastPathComponent().path

        if matches(k, any: ["zip", "archive", "compress to zip", "make zip", "zip it", "zip this"]) {
            let name = URL(fileURLWithPath: files[0]).deletingPathExtension().lastPathComponent
            return "zip -r \(shellQuote("\(dir)/\(name).zip")) \(quoted)"
        }

        if matches(k, any: ["what files are inside", "list zip", "zip contents", "inside this zip"]) {
            return "unzip -l \(quoted)"
        }

        if matches(k, any: ["unzip", "extract", "decompress", "unarchive"]) {
            return "unzip \(quoted) -d \"\(dir)\""
        }

        if k == "mp4" || matches(k, any: ["convert to mp4", "make mp4"]) {
            return files.map { convertVideoCommand(file: $0, ext: "mp4") }.joined(separator: " && ")
        }

        if k == "wav" || matches(k, any: ["convert to wav", "make wav"]) {
            return files.map { convertAudioCommand(file: $0, ext: "wav") }.joined(separator: " && ")
        }

        if matches(k, any: ["animated gif", "make gif", "convert to gif"]) {
            return files.map { animatedGIFCommand(file: $0, prompt: k) }.joined(separator: " && ")
        }

        if matches(k, any: ["bitrate", "video info", "media info"]) {
            return requireTool("ffprobe", installHint: "Install ffmpeg to inspect media files.") + " && ffprobe -hide_banner \(quoted)"
        }

        if matches(k, any: ["compress", "compress image", "compress it", "make smaller", "reduce size", "optimize", "optimise"]) {
            return files.map { imageCompressionCommand(for: $0) }.joined(separator: " && ")
        }

        if matches(k, any: ["trash", "delete", "remove", "move to trash", "bin"]) {
            let osaPaths = files.map { "POSIX file \(appleScriptQuote($0))" }.joined(separator: ", ")
            let script = "tell app \"Finder\" to move {\(osaPaths)} to trash"
            return "osascript -e \(shellQuote(script))"
        }

        if matches(k, any: ["what is this", "what's this", "what is it", "what type", "kind of file", "file type", "identify this", "tell me about this", "info", "metadata"]) {
            return inspectCommand(files: files)
        }

        if matches(k, any: ["dimensions", "image size", "resolution", "how big is this image"]) {
            return files.map { "sips -g pixelWidth -g pixelHeight \(shellQuote($0))" }.joined(separator: " && ")
        }

        if matches(k, any: ["rotate right", "rotate clockwise", "90 degrees clockwise"]) {
            return files.map { rotateImageCommand(file: $0, degrees: "90") }.joined(separator: " && ")
        }

        if matches(k, any: ["rotate left", "90 degrees counterclockwise", "90 degrees anticlockwise"]) {
            return files.map { rotateImageCommand(file: $0, degrees: "270") }.joined(separator: " && ")
        }

        if matches(k, any: ["resize"]) {
            if let height = firstNumber(before: ["px tall", "pixels tall", "high"], in: k) {
                return files.map { resizeImageCommand(file: $0, height: height) }.joined(separator: " && ")
            }
            if let width = firstNumber(before: ["px wide", "pixels wide", "wide"], in: k) {
                return files.map { resizeImageCommand(file: $0, width: width) }.joined(separator: " && ")
            }
        }

        if matches(k, any: ["border around", "add border", "10px border"]) {
            let px = firstNumber(before: ["px"], in: k) ?? "10"
            return files.map { imageMagickCommand(file: $0, suffix: "border", args: "-bordercolor white -border \(px)") }.joined(separator: " && ")
        }

        if matches(k, any: ["crop"]) {
            let px = firstNumber(before: ["pixels", "px"], in: k) ?? "50"
            return files.map { imageMagickCommand(file: $0, suffix: "cropped", args: "-shave \(px)x\(px)") }.joined(separator: " && ")
        }

        if matches(k, any: ["trim transparent", "trim whitespace", "trim edges", "remove transparent border"]) {
            return files.map { imageMagickCommand(file: $0, suffix: "trimmed", args: "-trim +repage") }.joined(separator: " && ")
        }

        if matches(k, any: ["3x3 grid", "grid of images", "contact sheet", "make grid"]) {
            return imageGridCommand(files: files, columns: firstGridColumnCount(in: k) ?? 3)
        }

        if matches(k, any: ["overlay text", "put text", "add text", "caption"]) {
            let text = quotedPromptText(from: keyword) ?? "Nest"
            return files.map { imageTextOverlayCommand(file: $0, text: text) }.joined(separator: " && ")
        }

        if matches(k, any: ["author", "who wrote", "pdf author"]) {
            return "mdls -name kMDItemAuthors -name kMDItemCreator \(quoted)"
        }

        if matches(k, any: ["where did i download", "downloaded from", "source url"]) {
            return "mdls -name kMDItemWhereFroms \(quoted)"
        }

        if matches(k, any: ["greyed out", "gray out", "grey out", "quarantine"]) {
            return "xattr -l \(quoted)"
        }

        if matches(k, any: ["extract text from this pdf", "extract text", "pdf text"]) {
            return requireTool("pdftotext", installHint: "Install poppler to extract PDF text.") + " && " + files.map { f in
                let out = URL(fileURLWithPath: f).deletingPathExtension().path + ".txt"
                return "pdftotext \(shellQuote(f)) \(shellQuote(out))"
            }.joined(separator: " && ")
        }

        if matches(k, any: ["merge these pdf", "merge pdf"]) {
            return requireTool("pdfunite", installHint: "Install poppler to merge PDFs.") + " && pdfunite \(quoted) \(shellQuote("\(dir)/merged.pdf"))"
        }

        if matches(k, any: ["split this pdf", "split pdf", "separate pages"]) {
            return requireTool("pdfseparate", installHint: "Install poppler to split PDFs.") + " && " + files.map { f in
                let out = URL(fileURLWithPath: f).deletingPathExtension().path + "-page-%d.pdf"
                return "pdfseparate \(shellQuote(f)) \(shellQuote(out))"
            }.joined(separator: " && ")
        }

        if matches(k, any: ["convert this docx to html", "docx to html"]) {
            return pandocConvert(files: files, ext: "html")
        }

        if matches(k, any: ["convert this docx to markdown", "docx to markdown", "docx to md"]) {
            return pandocConvert(files: files, ext: "md")
        }

        if matches(k, any: ["markdown to html", "md to html"]) {
            return pandocConvert(files: files, ext: "html")
        }

        if matches(k, any: ["docx to epub", "convert this docx to epub"]) {
            return pandocConvert(files: files, ext: "epub")
        }

        if matches(k, any: ["print this", "print"]) {
            return "lp \(quoted)"
        }

        switch k {
        case "jpg", "jpeg", "convert to jpg", "convert to jpeg":
            return files.map { f -> String in
                let out = URL(fileURLWithPath: f).deletingPathExtension().path + ".jpg"
                return "sips -s format jpeg \(shellQuote(f)) --out \(shellQuote(out))"
            }.joined(separator: " && ")

        case "png", "convert to png":
            return files.map { f -> String in
                let out = URL(fileURLWithPath: f).deletingPathExtension().path + ".png"
                return "sips -s format png \(shellQuote(f)) --out \(shellQuote(out))"
            }.joined(separator: " && ")

        case "webp", "convert to webp":
            return files.map { f -> String in
                let out = URL(fileURLWithPath: f).deletingPathExtension().path + ".webp"
                return "sips -s format webp \(shellQuote(f)) --out \(shellQuote(out))"
            }.joined(separator: " && ")

        case "heic", "convert to heic":
            return files.map { f -> String in
                let out = URL(fileURLWithPath: f).deletingPathExtension().path + ".heic"
                return "sips -s format heic \(shellQuote(f)) --out \(shellQuote(out))"
            }.joined(separator: " && ")

        case "copy path", "copy paths":
            return "printf %s \(shellQuote(files.joined(separator: "\n"))) | pbcopy"

        case "show hidden", "show hidden files":
            return "defaults write com.apple.finder AppleShowAllFiles YES && killall Finder"

        case "hide hidden", "hide hidden files":
            return "defaults write com.apple.finder AppleShowAllFiles NO && killall Finder"

        case "wc", "word count":
            return "wc -w \(quoted)"

        case "md5":
            return "md5 \(quoted)"

        case "open":
            return "open \(quoted)"

        default:
            return nil
        }
    }

    private static func folderAction(keyword k: String, folder: String) -> String? {
        if k == "pwd" {
            return "pwd"
        }

        if matches(k, any: ["show hidden", "show hidden files", "make invisible files visible"]) {
            return "defaults write com.apple.finder AppleShowAllFiles YES && killall Finder"
        }

        if matches(k, any: ["hide hidden", "hide hidden files"]) {
            return "defaults write com.apple.finder AppleShowAllFiles NO && killall Finder"
        }

        if matches(k, any: ["toggle dark mode"]) {
            return "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'"
        }

        if matches(k, any: ["processor", "what processor"]) {
            return "sysctl -n machdep.cpu.brand_string"
        }

        if matches(k, any: ["how much ram", "memory do i have"]) {
            return "system_profiler SPHardwareDataType | awk -F': ' '/Memory:/ {print $2}'"
        }

        if matches(k, any: ["keep my mac awake", "keep awake"]) {
            let hours = firstNumber(before: ["hour", "hours"], in: k) ?? "1"
            return "caffeinate -dimsu -t \(Int((Double(hours) ?? 1) * 3600))"
        }

        if matches(k, any: ["tidy up this folder", "organize by date", "organise by date"]) {
            return "cd \(shellQuote(folder)) && find . -maxdepth 1 -type f -print0 | while IFS= read -r -d '' f; do d=$(stat -f '%Sm' -t '%Y-%m-%d' \"$f\"); mkdir -p \"$d\"; mv \"$f\" \"$d/\"; done"
        }

        if matches(k, any: ["make a new readme", "new readme", "create readme", "make readme"]) {
            return "touch \(shellQuote(folder + "README.txt"))"
        }

        if matches(k, any: ["make a new index.html", "new index.html", "create index.html", "make index.html"]) {
            return "touch \(shellQuote(folder + "index.html"))"
        }

        if k.hasPrefix("mkdir ") || k.hasPrefix("new folder ") || k.hasPrefix("make folder ") {
            let rawName = k
                .replacingOccurrences(of: "mkdir ", with: "")
                .replacingOccurrences(of: "new folder ", with: "")
                .replacingOccurrences(of: "make folder ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawName.isEmpty else { return nil }
            return "mkdir -p \(shellQuote(folder + rawName))"
        }

        return nil
    }

    private static func normalized(_ keyword: String) -> String {
        keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matches(_ text: String, any phrases: [String]) -> Bool {
        phrases.contains { text == $0 || text.contains($0) }
    }

    private static func imageCompressionCommand(for file: String) -> String {
        let url = URL(fileURLWithPath: file)
        let output = url.deletingPathExtension().path + "-compressed.jpg"
        return "sips -s format jpeg -s formatOptions 65 \(shellQuote(file)) --out \(shellQuote(output))"
    }

    private static func convertVideoCommand(file: String, ext: String) -> String {
        let out = URL(fileURLWithPath: file).deletingPathExtension().path + ".\(ext)"
        return requireTool("ffmpeg", installHint: "Install ffmpeg to convert video.") + " && ffmpeg -y -i \(shellQuote(file)) \(shellQuote(out))"
    }

    private static func convertAudioCommand(file: String, ext: String) -> String {
        let out = URL(fileURLWithPath: file).deletingPathExtension().path + ".\(ext)"
        return requireTool("ffmpeg", installHint: "Install ffmpeg to convert audio.") + " && ffmpeg -y -i \(shellQuote(file)) \(shellQuote(out))"
    }

    private static func animatedGIFCommand(file: String, prompt: String) -> String {
        let out = URL(fileURLWithPath: file).deletingPathExtension().path + ".gif"
        let width = firstNumber(before: ["pixels wide", "px wide", "wide"], in: prompt) ?? "600"
        let fps = firstNumber(before: ["fps"], in: prompt) ?? "12"
        return requireTool("ffmpeg", installHint: "Install ffmpeg to make animated GIFs.") + " && ffmpeg -y -i \(shellQuote(file)) -vf \(shellQuote("fps=\(fps),scale=\(width):-1:flags=lanczos")) \(shellQuote(out))"
    }

    private static func rotateImageCommand(file: String, degrees: String) -> String {
        let out = URL(fileURLWithPath: file).deletingPathExtension().path + "-rotated." + URL(fileURLWithPath: file).pathExtension
        return "sips -r \(degrees) \(shellQuote(file)) --out \(shellQuote(out))"
    }

    private static func resizeImageCommand(file: String, width: String? = nil, height: String? = nil) -> String {
        let out = URL(fileURLWithPath: file).deletingPathExtension().path + "-resized." + URL(fileURLWithPath: file).pathExtension
        if let width {
            return "sips --resampleWidth \(width) \(shellQuote(file)) --out \(shellQuote(out))"
        }
        return "sips --resampleHeight \(height ?? "1080") \(shellQuote(file)) --out \(shellQuote(out))"
    }

    private static func imageMagickCommand(file: String, suffix: String, args: String) -> String {
        let url = URL(fileURLWithPath: file)
        let out = url.deletingPathExtension().path + "-\(suffix)." + url.pathExtension
        return requireTool("magick", installHint: "Install ImageMagick in Settings > Extra Tools, or run: brew install imagemagick") + " && magick \(shellQuote(file)) \(args) \(shellQuote(out))"
    }

    private static func imageGridCommand(files: [String], columns: Int) -> String {
        let dir = URL(fileURLWithPath: files[0]).deletingLastPathComponent().path
        let out = "\(dir)/image-grid.jpg"
        let quoted = files.map(shellQuote).joined(separator: " ")
        return requireTool("magick", installHint: "Install ImageMagick in Settings > Extra Tools, or run: brew install imagemagick") +
            " && magick montage \(quoted) -auto-orient -thumbnail 600x600 -tile \(columns)x -geometry +12+12 \(shellQuote(out))"
    }

    private static func imageTextOverlayCommand(file: String, text: String) -> String {
        let url = URL(fileURLWithPath: file)
        let out = url.deletingPathExtension().path + "-text." + url.pathExtension
        return requireTool("magick", installHint: "Install ImageMagick in Settings > Extra Tools, or run: brew install imagemagick") +
            " && magick \(shellQuote(file)) -auto-orient -gravity south -pointsize 72 -fill white -stroke black -strokewidth 3 -annotate +0+48 \(shellQuote(text)) \(shellQuote(out))"
    }

    private static func pandocConvert(files: [String], ext: String) -> String {
        requireTool("pandoc", installHint: "Install Pandoc for document conversion.") + " && " + files.map { file in
            let out = URL(fileURLWithPath: file).deletingPathExtension().path + ".\(ext)"
            return "pandoc \(shellQuote(file)) -o \(shellQuote(out))"
        }.joined(separator: " && ")
    }

    private static func requireTool(_ tool: String, installHint: String) -> String {
        "command -v \(tool) >/dev/null || { echo \(shellQuote(installHint)); exit 127; }"
    }

    private static func firstNumber(before markers: [String], in text: String) -> String? {
        for marker in markers {
            guard let range = text.range(of: marker) else { continue }
            let prefix = text[..<range.lowerBound]
            let parts = prefix.split { !$0.isNumber && $0 != "." }
            if let value = parts.last {
                return String(value)
            }
        }
        return nil
    }

    private static func firstGridColumnCount(in text: String) -> Int? {
        let pattern = #"(\d+)\s*x\s*(\d+)"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(text[range])
        return Int(match.components(separatedBy: "x").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    private static func quotedPromptText(from text: String) -> String? {
        let delimiters: [(Character, Character)] = [("\"", "\""), ("'", "'")]
        for (open, close) in delimiters {
            guard let start = text.firstIndex(of: open) else { continue }
            let next = text.index(after: start)
            guard next < text.endIndex,
                  let end = text[next...].firstIndex(of: close) else { continue }
            let value = String(text[next..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return nil
    }

    private static func inspectCommand(files: [String]) -> String {
        files.map { file in
            let q = shellQuote(file)
            return "printf 'File: %s\\n' \(q) && file -b \(q) && mdls -name kMDItemKind -name kMDItemContentType -name kMDItemFSSize \(q)"
        }.joined(separator: " && ")
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func appleScriptQuote(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
