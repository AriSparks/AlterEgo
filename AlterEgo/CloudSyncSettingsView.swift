import SwiftUI

struct CloudSyncSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var sync: CloudSyncManager
    @Environment(\.themePalette) private var palette

    var body: some View {
        Form {
            if CloudSyncManager.isCompiledIn {
                Section("iCloud Sync") {
                    Toggle("Sync with iCloud", isOn: $sync.isEnabled)

                    if sync.isEnabled {
                        if !sync.isAvailable {
                            Label("Sign in to iCloud on this device to sync.", systemImage: "exclamationmark.icloud")
                                .foregroundStyle(.orange)
                        }

                        if let lastSync = sync.lastSync {
                            Label(
                                "Last sync \(lastSync.formatted(date: .abbreviated, time: .shortened))",
                                systemImage: "clock.arrow.circlepath"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Button {
                            sync.upload(store.state)
                        } label: {
                            Label("Upload Current Data", systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(!sync.isAvailable)

                        Button {
                            if let remote = sync.download() {
                                store.mergeState(remote)
                                Haptics.impact()
                            }
                        } label: {
                            Label("Download and Merge", systemImage: "icloud.and.arrow.down")
                        }
                        .disabled(!sync.isAvailable)
                    }

                    if let error = sync.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text("iCloud sync uses key-value storage and is best for text data. Large image collections may exceed the sync limit; use Export & Import for a complete backup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("iCloud Sync") {
                    Label("Not included in this build", systemImage: "icloud.slash")
                    Text("The default build is configured for a free Apple developer account and keeps data on this device. See the README for the optional CLOUD_SYNC setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(ThemedBackground(fill: palette.background))
        .navigationTitle("iCloud Sync")
        .onChange(of: sync.isEnabled) { _, enabled in
            if enabled {
                sync.upload(store.state)
            }
        }
    }
}
