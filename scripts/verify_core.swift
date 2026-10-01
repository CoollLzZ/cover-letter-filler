import Foundation

@main
struct CoreVerification {
    static func main() {
        do {
            try verifiesPlaceholderDetectionAndReplacement()
            try verifiesOptionalTailoringCanBeBlank()
            try verifiesCountryConfiguration()
            if CommandLine.arguments.count == 2 {
                try verifiesRealTemplate(at: URL(fileURLWithPath: CommandLine.arguments[1]))
            }
            print("Core verification passed.")
        } catch {
            fputs("Core verification failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func verifiesPlaceholderDetectionAndReplacement() throws {
        let xml = """
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p>
            <w:r><w:t>Application for [Role </w:t></w:r>
            <w:r><w:t>Title] at [Company Name]</w:t></w:r>
          </w:p></w:body>
        </w:document>
        """
        try require(
            DocxTemplateService.placeholders(in: xml) == ["[Role Title]", "[Company Name]"],
            "Placeholder detection did not recognise tokens split across Word runs."
        )
        let rendered = DocxTemplateService.replacePlaceholders(
            in: xml,
            replacements: [
                "[Role Title]": "DevOps Engineer",
                "[Company Name]": "A & B Cloud",
            ]
        )
        try require(!rendered.contains("[Role Title]") && !rendered.contains("[Company Name]"), "Not every placeholder was replaced.")
        try require(rendered.contains("DevOps Engineer") && rendered.contains("A &amp; B Cloud"), "Replacement text was not XML-safe.")
    }

    private static func verifiesCountryConfiguration() throws {
        try require(Country.dubaiUAE.coverLetterFileName == "Dubai_Cover_Letter.docx", "Dubai filename is incorrect.")
        try require(Country.unitedStates.coverLetterFileName == "US_Cover_Letter.docx", "US filename is incorrect.")
        try require(Country.dubaiUAE.defaultCountry == "United Arab Emirates", "Dubai country default is incorrect.")
    }

    private static func verifiesOptionalTailoringCanBeBlank() throws {
        let xml = """
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p><w:r><w:t>[Add one sentence about this company.] I can discuss my experience.</w:t></w:r></w:p></w:body>
        </w:document>
        """
        let rendered = DocxTemplateService.replacePlaceholders(
            in: xml,
            replacements: ["[Add one sentence about this company.]": ""]
        )
        try require(rendered.contains(">I can discuss my experience.<"), "A blank optional tailoring field left unwanted whitespace in the letter.")
    }

    private static func verifiesRealTemplate(at template: URL) throws {
        let actual = try Set(DocxTemplateService.placeholders(in: template))
        let expected: Set<String> = [
            "[Date]",
            "[Hiring Manager Name]",
            "[Company Name]",
            "[Role Title]",
            "[City, Country]",
        ]
        try require(expected.isSubset(of: actual), "The real cover letter does not contain the expected standard placeholders.")
        try require(actual.contains(where: { $0.localizedCaseInsensitiveContains("add one sentence") }), "The employer-specific sentence placeholder is missing.")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw VerificationError(message: message) }
    }
}

private struct VerificationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
