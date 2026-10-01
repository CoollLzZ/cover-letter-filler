import SwiftUI

struct ContentView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedCountry) {
                Section("Countries") {
                    ForEach(Country.allCases) { country in
                        Label {
                            Text(country.rawValue)
                        } icon: {
                            Text(country.flag)
                        }
                        .tag(country)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.showFolderSettings = true
                } label: {
                    Label("Folder settings", systemImage: "folder.badge.gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding()
            }
        } detail: {
            CoverLetterFormView(store: store)
        }
        .tint(.blue)
        .sheet(isPresented: $store.showFolderSettings) {
            FolderSettingsView(store: store)
        }
    }
}

private struct CoverLetterFormView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                folders
                template
                form
                actions
                if let status = store.statusMessage {
                    Label(status, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(14)
                        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Unable to generate PDF", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .confirmationDialog(
            "Replace existing PDF?",
            isPresented: $store.showReplaceConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace PDF", role: .destructive) { store.replaceExistingPDF() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(store.outputFileName) already exists in \(store.configuration.pdfDirectory.lastPathComponent). The previous PDF will be replaced.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cover Letter Filler")
                .font(.largeTitle.bold())
            Text("\(store.selectedCountry.flag) \(store.selectedCountry.rawValue) cover letter")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                Text("Fill the placeholders found in your Word document. Your source file is never changed.")
                    .foregroundStyle(.secondary)
                Label(
                    PDFConverter.isBundled ? "Offline PDF engine included" : "Development build: offline PDF engine will be bundled for release",
                    systemImage: PDFConverter.isBundled ? "checkmark.seal.fill" : "wrench.and.screwdriver.fill"
                )
                .font(.footnote)
                .foregroundStyle(PDFConverter.isBundled ? .green : .secondary)
        }
    }

    private var folders: some View {
        GroupBox("Locations") {
            VStack(alignment: .leading, spacing: 14) {
                FolderRow(
                    title: "Word source",
                    path: store.configuration.sourceDirectory.path,
                    buttonTitle: "Choose folder",
                    action: { store.chooseSourceFolder() }
                )
                Divider()
                FolderRow(
                    title: "PDF destination",
                    path: store.configuration.pdfDirectory.path,
                    buttonTitle: "Choose folder",
                    action: { store.choosePDFFolder() }
                )
            }
            .padding(.vertical, 4)
        }
    }

    private var template: some View {
        GroupBox("Source cover letter") {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.templateURL?.lastPathComponent ?? store.selectedCountry.coverLetterFileName)
                        .fontWeight(.semibold)
                    Text("\(store.placeholders.count) placeholders detected")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open source letter") { store.openSourceLetter() }
                    .disabled(store.templateURL == nil)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var form: some View {
        GroupBox("Replace placeholders") {
            if store.placeholders.isEmpty {
                ContentUnavailableView(
                    "Cover letter not found",
                    systemImage: "doc.questionmark",
                    description: Text("Check the Word-source folder for \(store.selectedCountry.coverLetterFileName).")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(store.placeholders, id: \.self) { placeholder in
                        PlaceholderField(store: store, placeholder: placeholder)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Output filename")
                            .font(.subheadline.weight(.semibold))
                        Text(store.outputFileName)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                    Text("If this file already exists, the app will ask before replacing it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var actions: some View {
        HStack {
            if store.generatedPDF != nil {
                Button("Show in Finder") { store.revealGeneratedPDF() }
            }
            Spacer()
            Button {
                store.requestGeneration()
            } label: {
                if store.isGenerating {
                    ProgressView().controlSize(.small)
                    Text("Generating PDF")
                } else {
                    Text("Generate PDF")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.placeholders.isEmpty || store.isGenerating)
        }
    }
}

private struct FolderRow: View {
    let title: String
    let path: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(path)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(buttonTitle, action: action)
        }
    }
}

private struct PlaceholderField: View {
    @ObservedObject var store: AppStore
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.label(for: placeholder))
                .font(.subheadline.weight(.semibold))
            Text(placeholder)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            if placeholder == "[Date]" {
                DatePicker("", selection: $store.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.field)
                    .labelsHidden()
            } else if placeholder == "[City, Country]" {
                HStack {
                    TextField("City", text: $store.city)
                    if store.selectedCountry == .europe {
                        TextField("Country", text: $store.countryName)
                    } else {
                        Text(store.countryName)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else {
                TextField(store.label(for: placeholder), text: store.valueBinding(for: placeholder))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

private struct FolderSettingsView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Folder settings")
                    .font(.title2.bold())
                Text("Set the Word source and PDF destination independently for each country.")
                    .foregroundStyle(.secondary)
            }

            ForEach(Country.allCases) { country in
                let configuration = store.configuration(for: country)
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(country.flag) \(country.rawValue)")
                        .fontWeight(.semibold)
                    FolderRow(
                        title: "Word source",
                        path: configuration.sourceDirectory.path,
                        buttonTitle: "Change",
                        action: { store.chooseSourceFolder(for: country) }
                    )
                    FolderRow(
                        title: "PDF destination",
                        path: configuration.pdfDirectory.path,
                        buttonTitle: "Change",
                        action: { store.choosePDFFolder(for: country) }
                    )
                }
                .padding(14)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 780)
    }
}
