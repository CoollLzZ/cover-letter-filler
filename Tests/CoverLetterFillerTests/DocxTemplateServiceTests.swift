import XCTest
@testable import CoverLetterFiller

final class DocxTemplateServiceTests: XCTestCase {
    func testFindsUniquePlaceholdersAcrossWordRuns() {
        let xml = """
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p>
            <w:r><w:t>Application for [Role </w:t></w:r>
            <w:r><w:t>Title]</w:t></w:r>
            <w:r><w:t> at [Company Name]</w:t></w:r>
            <w:r><w:t> for [Role Title]</w:t></w:r>
          </w:p></w:body>
        </w:document>
        """

        XCTAssertEqual(
            DocxTemplateService.placeholders(in: xml),
            ["[Role Title]", "[Company Name]"]
        )
    }

    func testReplacesAPlaceholderSplitAcrossWordRunsAndEscapesText() {
        let xml = """
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p>
            <w:r><w:t>Application for [Role </w:t></w:r>
            <w:r><w:t>Title] at [Company Name]</w:t></w:r>
          </w:p></w:body>
        </w:document>
        """

        let rendered = DocxTemplateService.replacePlaceholders(
            in: xml,
            replacements: [
                "[Role Title]": "DevOps Engineer",
                "[Company Name]": "A & B Cloud",
            ]
        )

        XCTAssertFalse(rendered.contains("[Role Title]"))
        XCTAssertFalse(rendered.contains("[Company Name]"))
        XCTAssertTrue(rendered.contains("DevOps Engineer"))
        XCTAssertTrue(rendered.contains("A &amp; B Cloud"))
    }

    func testCountryProfilesUseExpectedCoverLetterNames() {
        XCTAssertEqual(Country.dubaiUAE.coverLetterFileName, "Dubai_Cover_Letter.docx")
        XCTAssertEqual(Country.unitedStates.coverLetterFileName, "US_Cover_Letter.docx")
        XCTAssertEqual(Country.dubaiUAE.defaultCountry, "United Arab Emirates")
        XCTAssertEqual(Country.europe.defaultCountry, "")
    }
}
