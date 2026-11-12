import SwiftUI
import UniformTypeIdentifiers

struct ExportImportSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.themePalette) private var palette

    @State private var exportDocument: BackupFileDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingImport: AlterEgoBackup?
    @State private var showImportOptions = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        Form {
            Section("Export") {
                Button {
                    prepareExport()
                } label: {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }

                Text("Creates a JSON file with all \(store.state.alters.count) alters and \(store.state.sessions.count) fronting sessions, including images.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Import") {
                Button {
                    showImporter = true
                } label: {
                    Label("Import Backup", systemImage: "square.and.arrow.down")
                }

                Text("You can merge an imported backup with your current data or replace everything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(ThemedBackground(fill: palette.background))
        .navigationTitle("Export & Import")
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "AlterEgo Backup"
        ) { result in
            exportDocument = nil
            switch result {
            case .success:
                showMessage(title: "Backup Exported", message: "Your backup file is ready.")
            case .failure(let error):
                showMessage(title: "Export Failed", message: error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .confirmationDialog(
            "Import this backup?",
            isPresented: $showImportOptions,
            titleVisibility: .visible,
            presenting: pendingImport
        ) { backup in
            Button("Merge with Current Data") {
                importBackup(backup, replace: false)
            }
            Button("Replace All Data", role: .destructive) {
                importBackup(backup, replace: true)
            }
            Button("Cancel", role: .cancel) {
                pendingImport = nil
            }
        } message: { backup in
            Text(
                "Exported \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened)). "
                + "Contains \(backup.state.alters.count) alters and \(backup.state.sessions.count) sessions."
            )
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func prepareExport() {
        do {
            let backup = AlterEgoBackup(
                formatVersion: AlterEgoBackup.currentFormatVersion,
                exportedAt: Date(),
                state: store.state
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(backup)

            exportDocument = BackupFileDocument(data: data)
            showExporter = true
        } catch {
            showMessage(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let backup = try decoder.decode(AlterEgoBackup.self, from: data)

                guard backup.formatVersion <= AlterEgoBackup.currentFormatVersion else {
                    showMessage(
                        title: "Newer Backup",
                        message: "This backup was created by a newer version of AlterEgo."
                    )
                    return
                }

                pendingImport = backup
                showImportOptions = true
            } catch {
                showMessage(title: "Import Failed", message: error.localizedDescription)
            }
        case .failure(let error):
            showMessage(title: "Import Failed", message: error.localizedDescription)
        }
    }

    private func importBackup(_ backup: AlterEgoBackup, replace: Bool) {
        if replace {
            store.replaceState(backup.state)
        } else {
            store.mergeState(backup.state)
        }

        pendingImport = nil
        Haptics.impact()
        showMessage(
            title: replace ? "Data Replaced" : "Backup Merged",
            message: "AlterEgo now has \(store.state.alters.count) alters and \(store.state.sessions.count) sessions."
        )
    }

    private func showMessage(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
