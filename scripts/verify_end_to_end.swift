import Foundation

@main
struct EndToEndVerification {
    static func main() {
        guard CommandLine.arguments.count == 3 else {
            fputs("Usage: verify-end-to-end <cover-letter.docx> <soffice-path>\n", stderr)
            exit(64)
        }

        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cover-letter-e2e-\(UUID().uuidString)", isDirectory: true)
        let keepOutput = ProcessInfo.processInfo.environment["E2E_KEEP_OUTPUT"] == "1"

        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer {
                if !keepOutput { try? FileManager.default.removeItem(at: root) }
            }

            let tokens = try DocxTemplateService.placeholders(in: source)
            var replacements: [String: String] = [:]
            for token in tokens {
                switch token {
                case "[Date]": replacements[token] = "29 September 2026"
                case "[Hiring Manager Name]": replacements[token] = "Hiring Manager"
                case "[Company Name]": replacements[token] = "Acme Systems"
                case "[Role Title]": replacements[token] = "DevOps Engineer"
                case "[City, Country]": replacements[token] = "Dubai, United Arab Emirates"
                case let value where value.localizedCaseInsensitiveContains("add one sentence"):
                    replacements[token] = "Acme Systems' platform reliability work is especially relevant to the automation and production-support experience I bring."
                default:
                    throw VerificationError(message: "Unexpected placeholder: \(token)")
                }
            }

            let temporary = try DocxTemplateService.temporaryDocument(from: source, replacements: replacements)
            defer { temporary.cleanup() }
            let remainingPlaceholders = try DocxTemplateService.placeholders(in: temporary.document)
            try require(remainingPlaceholders.isEmpty, "The generated DOCX still contains a placeholder.")

            let output = root
                .appendingPathComponent(source.deletingPathExtension().lastPathComponent)
                .appendingPathExtension("pdf")
            try PDFConverter.export(document: temporary.document, to: output)

            let data = try Data(contentsOf: output)
            try require(data.count > 1_000, "The generated PDF is unexpectedly small.")
            try require(String(data: data.prefix(4), encoding: .ascii) == "%PDF", "The generated file is not a PDF.")
            print(output.path)
        } catch {
            fputs("End-to-end verification failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw VerificationError(message: message) }
    }
}

private struct VerificationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
