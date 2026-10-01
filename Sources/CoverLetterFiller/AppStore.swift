import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    private static let defaultRoot = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0].appendingPathComponent("Final Job Applications 2026", isDirectory: true)

    @Published var selectedCountry: Country = .dubaiUAE {
        didSet { resetFormAndRefreshTemplate() }
    }
    @Published private(set) var placeholders: [String] = []
    @Published var values: [String: String] = [:]
    @Published var selectedDate = Date()
    @Published var city = "Dubai"
    @Published var countryName = "United Arab Emirates"
    @Published var statusMessage: String?
    @Published var generatedPDF: URL?
    @Published var errorMessage: String?
    @Published var isGenerating = false
    @Published var showReplaceConfirmation = false
    @Published var showFolderSettings = false

    /// Some legacy templates contain an optional drafting prompt. It is never
    /// shown to the user because this app's job is only to fill the fixed
    /// application placeholders. The prompt is cleared during generation.
    private var hiddenPlaceholders: [String] = []

    init() {
        resetFormAndRefreshTemplate()
    }

    func configuration(for country: Country) -> FolderConfiguration {
        FolderConfiguration(
            sourceDirectory: savedDirectory(for: country, kind: .source)
                ?? Self.defaultRoot.appendingPathComponent(country.rawValue, isDirectory: true),
            pdfDirectory: savedDirectory(for: country, kind: .pdf)
                ?? Self.defaultRoot.appendingPathComponent("PDF", isDirectory: true)
                    .appendingPathComponent(country.rawValue, isDirectory: true)
        )
    }

    var configuration: FolderConfiguration { configuration(for: selectedCountry) }

    var templateURL: URL? {
        let expected = configuration.sourceDirectory.appendingPathComponent(selectedCountry.coverLetterFileName)
        if FileManager.default.fileExists(atPath: expected.path) { return expected }

        let candidates = (try? FileManager.default.contentsOfDirectory(
            at: configuration.sourceDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return candidates.first { $0.pathExtension.lowercased() == "docx" && $0.lastPathComponent.localizedCaseInsensitiveContains("cover_letter") }
    }

    var outputURL: URL? {
        guard let templateURL else { return nil }
        return configuration.pdfDirectory
            .appendingPathComponent(templateURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("pdf")
    }

    var outputFileName: String { outputURL?.lastPathComponent ?? "Cover_Letter.pdf" }

    var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }

    func valueBinding(for placeholder: String) -> Binding<String> {
        Binding(
            get: { self.values[placeholder, default: ""] },
            set: { self.values[placeholder] = $0 }
        )
    }

    func chooseSourceFolder(for country: Country? = nil) {
        chooseFolder(for: country ?? selectedCountry, kind: .source)
    }

    func choosePDFFolder(for country: Country? = nil) {
        chooseFolder(for: country ?? selectedCountry, kind: .pdf)
    }

    func openSourceLetter() {
        guard let templateURL else { return }
        NSWorkspace.shared.open(templateURL)
    }

    func revealGeneratedPDF() {
        guard let generatedPDF else { return }
        NSWorkspace.shared.activateFileViewerSelecting([generatedPDF])
    }

    func requestGeneration() {
        do {
            let request = try makeRequest()
            if FileManager.default.fileExists(atPath: request.outputPDF.path) {
                showReplaceConfirmation = true
            } else {
                generate(request)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replaceExistingPDF() {
        showReplaceConfirmation = false
        do {
            generate(try makeRequest())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generate(_ request: GenerationRequest) {
        isGenerating = true
        statusMessage = nil
        generatedPDF = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let temporary = try DocxTemplateService.temporaryDocument(
                    from: request.sourceDocument,
                    replacements: request.replacements
                )
                defer { temporary.cleanup() }
                try PDFConverter.export(document: temporary.document, to: request.outputPDF)
                DispatchQueue.main.async {
                    self?.isGenerating = false
                    self?.generatedPDF = request.outputPDF
                    self?.statusMessage = "PDF saved to \(request.outputPDF.deletingLastPathComponent().path)."
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isGenerating = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func makeRequest() throws -> GenerationRequest {
        guard let source = templateURL else {
            throw AppError.templateMissing(configuration.sourceDirectory.appendingPathComponent(selectedCountry.coverLetterFileName))
        }
        guard let output = outputURL else { throw AppError.invalidDocument }
        guard !placeholders.isEmpty else { throw AppError.noPlaceholders(source) }

        var replacements = values
        for placeholder in placeholders {
            if placeholder == "[Date]" {
                replacements[placeholder] = formatter.string(from: selectedDate)
            } else if placeholder == "[City, Country]" {
                let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedCountry = countryName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedCity.isEmpty else { throw AppError.blankField("City") }
                guard !trimmedCountry.isEmpty else { throw AppError.blankField("Country") }
                replacements[placeholder] = "\(trimmedCity), \(trimmedCountry)"
            } else if replacements[placeholder, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw AppError.blankField(label(for: placeholder))
            }
        }

        // Clear optional authoring prompts that may be embedded in an older
        // cover-letter template. They are not fields the applicant should fill.
        for placeholder in hiddenPlaceholders {
            replacements[placeholder] = ""
        }

        return GenerationRequest(
            sourceDocument: source,
            outputPDF: output,
            replacements: replacements
        )
    }

    func label(for placeholder: String) -> String {
        if placeholder == "[Date]" { return "Date" }
        if placeholder == "[Hiring Manager Name]" { return "Hiring manager name" }
        if placeholder == "[Company Name]" { return "Company name" }
        if placeholder == "[Role Title]" { return "Role title" }
        if placeholder == "[City, Country]" { return "City and country" }
        return placeholder.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    }

    func isEmployerSpecificSentence(_ placeholder: String) -> Bool {
        placeholder.localizedCaseInsensitiveContains("add one sentence")
    }

    private func resetFormAndRefreshTemplate() {
        values = [:]
        selectedDate = Date()
        city = selectedCountry.defaultCity
        countryName = selectedCountry.defaultCountry
        generatedPDF = nil
        statusMessage = nil

        guard let templateURL else {
            placeholders = []
            return
        }
        do {
            let detected = try DocxTemplateService.placeholders(in: templateURL)
            hiddenPlaceholders = detected.filter(isEmployerSpecificSentence)
            placeholders = detected.filter { !isEmployerSpecificSentence($0) }
            for placeholder in placeholders {
                values[placeholder] = defaultValue(for: placeholder)
            }
        } catch {
            placeholders = []
            hiddenPlaceholders = []
            errorMessage = error.localizedDescription
        }
    }

    private func defaultValue(for placeholder: String) -> String {
        switch placeholder {
        case "[Hiring Manager Name]": "Hiring Manager"
        case "[Role Title]": "DevOps Engineer"
        default: ""
        }
    }

    private enum FolderKind: String {
        case source
        case pdf
    }

    private func preferenceKey(for country: Country, kind: FolderKind) -> String {
        "\(kind.rawValue)-folder-\(country.rawValue)"
    }

    private func savedDirectory(for country: Country, kind: FolderKind) -> URL? {
        UserDefaults.standard.string(forKey: preferenceKey(for: country, kind: kind))
            .map(URL.init(fileURLWithPath:))
    }

    private func chooseFolder(for country: Country, kind: FolderKind) {
        let panel = NSOpenPanel()
        panel.title = kind == .source ? "Choose Word source folder" : "Choose PDF destination folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = configuration(for: country).sourceDirectory

        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: preferenceKey(for: country, kind: kind))
        if country == selectedCountry { resetFormAndRefreshTemplate() }
    }
}
