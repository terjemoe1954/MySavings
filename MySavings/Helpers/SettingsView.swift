//
//  SettingsView.swift
//  Income
//
//  Created by Terje Moe on 09/11/2025.
//

import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var invoices: [Invoice]
    @Query private var customers: [Customer]

    @Binding var name: String
    @Binding var darkModeEnabled: Bool
    @Binding var showName: Bool
    @Binding var showStatus: Bool

    @State private var exportFile: SaldoPilotExportFile?
    @State private var isPreparingExport = false
    @State private var exportErrorMessage: String?
    @State private var showingRestorePicker = false
    @State private var pendingRestore: SaldoPilotRestorePackage?
    @State private var restoreErrorMessage: String?
    @State private var restoreSuccessMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Display"),
                    footer: Text("")
                ) {
                    Toggle(isOn: $darkModeEnabled) {
                        Text(!darkModeEnabled ? "Dag modus" : "Natt modus")
                    }

                    Toggle(isOn: $showName) {
                        Text(!showName ? "Skjult bruker navn" : "Vist bruker navn")
                    }

                    HStack {
                        Text("Ditt Navn:          ")
                        TextField("Navn:", text: $name)
                    }

                    Toggle(isOn: $showStatus) {
                        Text(!showStatus ? "Tillat endring av Status (Av)" : "Tillat endring av Status (På)")
                    }
                    .foregroundStyle(.red)
                }

                SaldoPilotExportSection(
                    transactionCount: invoices.count,
                    isPreparing: isPreparingExport,
                    exportAction: prepareSaldoPilotExport
                )

                SaldoPilotRestoreSection {
                    showingRestorePicker = true
                }

                Section {
                    Link(destination: URL(string: Constants.web)!) {
                        Label("Les VG", systemImage: "globe")
                    }

                    HStack {
                        Image(systemName: "envelope")
                        Link(
                            "Kontakt meg via mail",
                            destination: URL(string: Constants.email)!
                        )
                    }

                    HStack {
                        Image(systemName: "phone")
                        Link(
                            "Ring meg",
                            destination: URL(string: Constants.phone)!
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ferdig") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .foregroundStyle(darkModeEnabled ? Color.white : Color.black)
            .font(.system(size: 16, weight: .semibold))
            .navigationTitle("Instillinger")
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .sheet(item: $exportFile) { file in
            SaldoPilotShareSheet(fileURL: file.url)
        }
        .fileImporter(
            isPresented: $showingRestorePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleRestoreFile
        )
        .alert(
            "Erstatt alle data?",
            isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            )
        ) {
            Button("Avbryt", role: .cancel) {
                pendingRestore = nil
            }
            Button("Slett og gjenopprett", role: .destructive) {
                performRestore()
            }
        } message: {
            if let pendingRestore {
                Text(
                    "\(pendingRestore.transactionCount) bilag og " +
                    "\(pendingRestore.categoryCount) klienter vil erstatte alle data. " +
                    "Endringen synkroniseres til iCloud."
                )
            }
        }
        .alert(
            "Kunne ikke eksportere",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .alert(
            "Kunne ikke gjenopprette",
            isPresented: Binding(
                get: { restoreErrorMessage != nil },
                set: { if !$0 { restoreErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreErrorMessage ?? "")
        }
        .alert(
            "Gjenoppretting fullført",
            isPresented: Binding(
                get: { restoreSuccessMessage != nil },
                set: { if !$0 { restoreSuccessMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreSuccessMessage ?? "")
        }
    }

    private func prepareSaldoPilotExport() {
        guard !isPreparingExport else { return }
        isPreparingExport = true

        Task { @MainActor in
            await Task.yield()

            do {
                let url = try SaldoPilotExporter.makeTemporaryFile(
                    invoices: invoices,
                    customers: customers,
                    displayName: name,
                    darkModeEnabled: darkModeEnabled,
                    showName: showName,
                    showStatus: showStatus
                )
                isPreparingExport = false
                exportFile = SaldoPilotExportFile(url: url)
            } catch {
                isPreparingExport = false
                exportErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleRestoreFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            pendingRestore = try SaldoPilotImporter.decode(data)
        } catch {
            restoreErrorMessage = error.localizedDescription
        }
    }

    private func performRestore() {
        guard let package = pendingRestore else { return }

        do {
            try SaldoPilotImporter.replaceData(
                with: package,
                in: modelContext
            )
            name = package.settings.displayName
            darkModeEnabled = package.settings.darkModeEnabled
            showName = package.settings.showName
            showStatus = package.settings.showStatus
            pendingRestore = nil
            restoreSuccessMessage =
                "\(package.transactionCount) bilag og " +
                "\(package.categoryCount) klienter er gjenopprettet. " +
                "La appen være åpen mens iCloud synkroniserer."
        } catch {
            pendingRestore = nil
            restoreErrorMessage = error.localizedDescription
        }
    }
}

private struct SaldoPilotRestoreSection: View {
    let restoreAction: () -> Void

    var body: some View {
        Section {
            Button(role: .destructive, action: restoreAction) {
                Label("Gjenopprett fra backup", systemImage: "arrow.counterclockwise.icloud")
            }
        } header: {
            Text("Gjenoppretting")
        } footer: {
            Text(
                "Backupfilen kontrolleres før alle lokale data erstattes. " +
                "Endringene synkroniseres til iCloud."
            )
        }
    }
}

private struct SaldoPilotExportSection: View {
    let transactionCount: Int
    let isPreparing: Bool
    let exportAction: () -> Void

    var body: some View {
        Section {
            Button(action: exportAction) {
                if isPreparing {
                    Label {
                        Text("Klargjør eksport…")
                    } icon: {
                        ProgressView()
                    }
                } else {
                    Label("Til SaldoPilot", systemImage: "square.and.arrow.up")
                }
            }
            .disabled(transactionCount == 0 || isPreparing)
        } header: {
            Text("Sikkerhetskopi og eksport")
        } footer: {
            if transactionCount == 0 {
                Text("Det finnes ingen bilag å eksportere.")
            } else {
                Text("\(transactionCount) bilag eksporteres i SaldoPilot-format.")
            }
        }
    }
}

private struct SaldoPilotExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SaldoPilotShareSheet: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

#Preview {
    SettingsView(
        name: .constant("Tomle Hue"),
        darkModeEnabled: .constant(false),
        showName: .constant(false),
        showStatus: .constant(false)
    )
    .modelContainer(for: Invoice.self, inMemory: true)
}
