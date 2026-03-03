/**
 * ImportHistoryView.swift
 *
 * UI for importing Spotify Extended Streaming History.
 * Allows users to upload their data export from Spotify's privacy settings.
 */

import SwiftUI
import UniformTypeIdentifiers

struct ImportHistoryView: View {
    @StateObject private var importService = SpotifyImportService.shared
    @StateObject private var appState = AppState.shared
    @State private var showFilePicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.spacing24) {
                    // Header explanation
                    infoSection

                    // Current import progress (if any)
                    if let currentImport = importService.currentImport {
                        importProgressSection(currentImport)
                    }

                    // Upload button
                    if importService.currentImport == nil || importService.currentImport?.isComplete == true || importService.currentImport?.isFailed == true {
                        uploadSection
                    }

                    // Previous imports
                    if !importService.imports.isEmpty {
                        previousImportsSection
                    }
                }
                .padding(Spacing.spacing20)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Import History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        importService.stopPolling()
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: SpotifyImportService.supportedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadImports()
        }
    }

    // MARK: - Sections

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            HStack(spacing: Spacing.spacing12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 32))
                    .foregroundColor(.goldPrimary)

                VStack(alignment: .leading, spacing: Spacing.spacing4) {
                    Text("Import Your Full History")
                        .font(.h3)
                        .foregroundColor(.textPrimary)

                    Text("Upload your Spotify Extended Streaming History export")
                        .font(.bodySmall)
                        .foregroundColor(.textSecondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: Spacing.spacing8) {
                instructionRow(number: 1, text: "Go to spotify.com/account/privacy")
                instructionRow(number: 2, text: "Request \"Extended streaming history\"")
                instructionRow(number: 3, text: "Wait for email (up to 30 days)")
                instructionRow(number: 4, text: "Download and upload the .zip file here")
            }

            if importService.totalEventsImported > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.emerald600)
                    Text("\(formatNumber(importService.totalEventsImported)) events imported")
                        .font(.bodySmall)
                        .foregroundColor(.emerald600)
                }
                .padding(.top, Spacing.spacing8)
            }
        }
        .padding(Spacing.spacing16)
        .background(Color.surfaceCard)
        .cornerRadius(Radius.large)
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.spacing12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.emerald600)
                .clipShape(Circle())

            Text(text)
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
    }

    private func importProgressSection(_ status: ImportStatus) -> some View {
        VStack(alignment: .leading, spacing: Spacing.spacing16) {
            HStack {
                Text("Import Progress")
                    .font(.h3)
                    .foregroundColor(.textPrimary)

                Spacer()

                statusBadge(status.status)
            }

            if let filename = status.originalFilename {
                Text(filename)
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: Spacing.spacing8) {
                ProgressView(value: Double(status.progress.percentage) / 100.0)
                    .tint(.goldPrimary)

                HStack {
                    Text("\(status.progress.percentage)%")
                        .font(.captionBold)
                        .foregroundColor(.goldPrimary)

                    Spacer()

                    Text("\(status.progress.processedFiles)/\(status.progress.totalFiles) files")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }

            // Stats
            HStack(spacing: Spacing.spacing16) {
                statItem(
                    value: formatNumber(status.progress.rowsInserted),
                    label: "Inserted"
                )
                statItem(
                    value: formatNumber(status.progress.rowsDeduped),
                    label: "Duplicates"
                )
                statItem(
                    value: formatNumber(status.progress.totalRowsSeen),
                    label: "Total"
                )
            }

            if let error = status.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.bodySmall)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(Spacing.spacing16)
        .background(Color.surfaceCard)
        .cornerRadius(Radius.large)
    }

    private var uploadSection: some View {
        Button(action: { showFilePicker = true }) {
            HStack(spacing: Spacing.spacing12) {
                if importService.isUploading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 20))
                }

                Text(importService.isUploading ? "Uploading..." : "Select File to Import")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.spacing16)
            .background(Color.emerald700)
            .foregroundColor(.white)
            .cornerRadius(Radius.large)
        }
        .disabled(importService.isUploading)
    }

    private var previousImportsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            Text("Previous Imports")
                .font(.h3)
                .foregroundColor(.textPrimary)

            ForEach(importService.imports, id: \.id) { importItem in
                importRow(importItem)
            }
        }
    }

    private func importRow(_ item: ImportListItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.spacing4) {
                Text(item.originalFilename ?? "Import")
                    .font(.bodyDefault)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.spacing8) {
                    Text(formatDate(item.createdAt))
                        .font(.caption)
                        .foregroundColor(.textTertiary)

                    Text("•")
                        .foregroundColor(.textTertiary)

                    Text("\(formatNumber(item.rowsInserted)) events")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }

            Spacer()

            statusBadge(item.status)
        }
        .padding(Spacing.spacing12)
        .background(Color.surfaceCard)
        .cornerRadius(Radius.medium)
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(statusColor(status))
            .padding(.horizontal, Spacing.spacing8)
            .padding(.vertical, Spacing.spacing4)
            .background(statusColor(status).opacity(0.15))
            .cornerRadius(Radius.small)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: Spacing.spacing4) {
            Text(value)
                .font(.h3)
                .foregroundColor(.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "complete": return .emerald600
        case "failed": return .red
        case "processing", "uploading": return .goldPrimary
        default: return .textTertiary
        }
    }

    private func formatNumber(_ num: Int64) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            Task {
                await uploadFile(fileURL)
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func uploadFile(_ url: URL) async {
        guard let jwt = appState.jwt else {
            errorMessage = "Please log in first"
            showError = true
            return
        }

        do {
            try await importService.importFile(from: url, jwt: jwt)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func loadImports() async {
        guard let jwt = appState.jwt else { return }
        try? await importService.listImports(jwt: jwt)
    }
}

struct ImportHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ImportHistoryView()
    }
}
