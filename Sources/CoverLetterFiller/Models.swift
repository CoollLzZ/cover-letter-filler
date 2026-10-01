import Foundation

enum Country: String, CaseIterable, Identifiable {
    case india = "India"
    case dubaiUAE = "Dubai UAE"
    case europe = "Europe"
    case unitedStates = "United States"

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .india: "🇮🇳"
        case .dubaiUAE: "🇦🇪"
        case .europe: "🇪🇺"
        case .unitedStates: "🇺🇸"
        }
    }

    var coverLetterFileName: String {
        switch self {
        case .india: "India_Cover_Letter.docx"
        case .dubaiUAE: "Dubai_Cover_Letter.docx"
        case .europe: "Europe_Cover_Letter.docx"
        case .unitedStates: "US_Cover_Letter.docx"
        }
    }

    var defaultCity: String {
        switch self {
        case .india: "Pune"
        case .dubaiUAE: "Dubai"
        case .europe, .unitedStates: ""
        }
    }

    var defaultCountry: String {
        switch self {
        case .india: "India"
        case .dubaiUAE: "United Arab Emirates"
        case .europe: ""
        case .unitedStates: "United States"
        }
    }
}

struct FolderConfiguration: Equatable {
    let sourceDirectory: URL
    let pdfDirectory: URL
}

struct GenerationRequest: Sendable {
    let sourceDocument: URL
    let outputPDF: URL
    let replacements: [String: String]
}

enum AppError: LocalizedError {
    case sourceFolderMissing(URL)
    case templateMissing(URL)
    case noPlaceholders(URL)
    case blankField(String)
    case noPDFConverter
    case conversionFailed(String)
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .sourceFolderMissing(let url):
            "The source folder could not be found: \(url.path)"
        case .templateMissing(let url):
            "The configured Word cover letter could not be found: \(url.path)"
        case .noPlaceholders(let url):
            "No placeholders were found in \(url.lastPathComponent)."
        case .blankField(let field):
            "Please complete \(field)."
        case .noPDFConverter:
            "The bundled PDF engine is unavailable. This development build must be packaged with its internal document engine before it can generate PDFs."
        case .conversionFailed(let details):
            "PDF conversion failed. \(details)"
        case .invalidDocument:
            "This Word document could not be read as a DOCX file."
        }
    }
}
