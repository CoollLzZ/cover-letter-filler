import Foundation

enum PDFConverter {
    static func export(document: URL, to target: URL) throws {
        guard let converter = availableConverter else {
            throw AppError.noPDFConverter
        }

        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("pdf-conversion-\(UUID().uuidString)", isDirectory: true)
        let conversionOutput = root.appendingPathComponent("output", isDirectory: true)
        let profile = root.appendingPathComponent("profile", isDirectory: true)
        try fileManager.createDirectory(at: conversionOutput, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: profile, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let profileURL = profile.absoluteString
        _ = try CommandRunner.run(
            executable: converter,
            arguments: [
                "--headless",
                "-env:UserInstallation=\(profileURL)",
                "--convert-to", "pdf",
                "--outdir", conversionOutput.path,
                document.path,
            ],
            environment: ["HOME": profile.path]
        )

        let generated = conversionOutput
            .appendingPathComponent(document.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("pdf")
        guard fileManager.fileExists(atPath: generated.path) else {
            throw AppError.conversionFailed("LibreOffice did not produce a PDF file.")
        }

        try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        try fileManager.copyItem(at: generated, to: target)
    }

    static var isBundled: Bool {
        bundledConverter != nil
    }

    static var availableConverter: URL? {
        if let bundledConverter { return bundledConverter }

        // This developer-only fallback allows local validation before the release bundle is assembled.
        // It is deliberately not exposed in the app's user interface.
        #if DEBUG
        if let developmentConverter = ProcessInfo.processInfo.environment["SOFFICE_PATH"]
            .map(URL.init(fileURLWithPath:)),
           FileManager.default.isExecutableFile(atPath: developmentConverter.path) {
            return developmentConverter
        }
        #endif

        return nil
    }

    private static var bundledConverter: URL? {
        let fileManager = FileManager.default
        let candidate = Bundle.main.resourceURL?
            .appendingPathComponent("LibreOffice.app", isDirectory: true)
            .appendingPathComponent("Contents/MacOS/soffice")
        guard let candidate, fileManager.isExecutableFile(atPath: candidate.path) else { return nil }
        return candidate
    }
}
