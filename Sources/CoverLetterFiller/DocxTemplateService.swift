import Foundation

struct TemporaryDocument {
    let root: URL
    let document: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

enum DocxTemplateService {
    private struct TextNode {
        let xmlContentRange: Range<String.Index>
        let startOffset: Int
        let endOffset: Int
        var text: String
    }

    static func placeholders(in document: URL) throws -> [String] {
        let xml = try documentXML(in: document)
        return placeholders(in: xml)
    }

    static func placeholders(in xml: String) -> [String] {
        let text = visibleText(in: xml)
        guard let regex = try? NSRegularExpression(pattern: #"\[[^\[\]]+\]"#) else { return [] }
        let all = NSRange(text.startIndex..., in: text)
        var seen = Set<String>()
        return regex.matches(in: text, range: all).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let token = String(text[range])
            return seen.insert(token).inserted ? token : nil
        }
    }

    static func temporaryDocument(
        from source: URL,
        replacements: [String: String]
    ) throws -> TemporaryDocument {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("cover-letter-\(UUID().uuidString)", isDirectory: true)
        let expanded = root.appendingPathComponent("expanded", isDirectory: true)
        try fileManager.createDirectory(at: expanded, withIntermediateDirectories: true)

        do {
            _ = try CommandRunner.run(
                executable: URL(fileURLWithPath: "/usr/bin/unzip"),
                arguments: ["-qq", source.path, "-d", expanded.path]
            )
            let xmlURL = expanded.appendingPathComponent("word/document.xml")
            let xml = try String(contentsOf: xmlURL, encoding: .utf8)
            let replaced = replacePlaceholders(in: xml, replacements: replacements)
            try replaced.write(to: xmlURL, atomically: true, encoding: .utf8)

            let output = root.appendingPathComponent(source.lastPathComponent)
            _ = try CommandRunner.run(
                executable: URL(fileURLWithPath: "/usr/bin/zip"),
                arguments: ["-qry", output.path, "."],
                currentDirectory: expanded
            )
            return TemporaryDocument(root: root, document: output)
        } catch {
            try? fileManager.removeItem(at: root)
            throw error
        }
    }

    static func replacePlaceholders(in xml: String, replacements: [String: String]) -> String {
        var nodes = textNodes(in: xml)
        let fullText = nodes.map(\.text).joined()
        guard let regex = try? NSRegularExpression(pattern: #"\[[^\[\]]+\]"#) else { return xml }

        let fullRange = NSRange(fullText.startIndex..., in: fullText)
        let matches = regex.matches(in: fullText, range: fullRange)

        for match in matches.reversed() {
            guard
                let matchRange = Range(match.range, in: fullText),
                let replacement = replacements[String(fullText[matchRange])]
            else { continue }

            var effectiveRange = matchRange
            if replacement.isEmpty,
               String(fullText[matchRange]).localizedCaseInsensitiveContains("add one sentence"),
               effectiveRange.upperBound < fullText.endIndex,
               fullText[effectiveRange.upperBound].isWhitespace {
                effectiveRange = effectiveRange.lowerBound..<fullText.index(after: effectiveRange.upperBound)
            }

            let start = fullText.distance(from: fullText.startIndex, to: effectiveRange.lowerBound)
            let end = fullText.distance(from: fullText.startIndex, to: effectiveRange.upperBound)
            let affected = nodes.indices.filter { nodes[$0].startOffset < end && nodes[$0].endOffset > start }
            guard let first = affected.first else { continue }

            for index in affected {
                let localStart = max(start, nodes[index].startOffset) - nodes[index].startOffset
                let localEnd = min(end, nodes[index].endOffset) - nodes[index].startOffset
                let from = nodes[index].text.index(nodes[index].text.startIndex, offsetBy: localStart)
                let to = nodes[index].text.index(nodes[index].text.startIndex, offsetBy: localEnd)
                nodes[index].text.replaceSubrange(from..<to, with: index == first ? replacement : "")
            }
        }

        var output = xml
        for node in nodes.sorted(by: { $0.xmlContentRange.lowerBound > $1.xmlContentRange.lowerBound }) {
            output.replaceSubrange(node.xmlContentRange, with: escapeXML(node.text))
        }
        return output
    }

    private static func documentXML(in document: URL) throws -> String {
        let xml = try CommandRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/unzip"),
            arguments: ["-p", document.path, "word/document.xml"]
        )
        guard !xml.isEmpty else { throw AppError.invalidDocument }
        return xml
    }

    private static func textNodes(in xml: String) -> [TextNode] {
        guard let regex = try? NSRegularExpression(pattern: #"<w:t(?:\s[^>]*)?>(.*?)</w:t>"#, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let searchRange = NSRange(xml.startIndex..., in: xml)
        var offset = 0
        return regex.matches(in: xml, range: searchRange).compactMap { match in
            guard let contents = Range(match.range(at: 1), in: xml) else { return nil }
            let text = unescapeXML(String(xml[contents]))
            defer { offset += text.count }
            return TextNode(
                xmlContentRange: contents,
                startOffset: offset,
                endOffset: offset + text.count,
                text: text
            )
        }
    }

    private static func visibleText(in xml: String) -> String {
        textNodes(in: xml).map(\.text).joined()
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func unescapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

enum CommandRunner {
    @discardableResult
    static func run(
        executable: URL,
        arguments: [String],
        currentDirectory: URL? = nil,
        environment: [String: String] = [:]
    ) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = output
        process.standardError = errors
        if !environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw AppError.conversionFailed(stderr.isEmpty ? "The command did not complete successfully." : stderr)
        }
        return stdout
    }
}
