/**
 * SpotifyImportService.swift
 *
 * Handles importing Spotify Extended Streaming History exports.
 * Users can upload their .zip or .json export files from Spotify's
 * privacy data download.
 */

import Foundation
import UniformTypeIdentifiers

// MARK: - Import Models

struct ImportJob: Codable {
    let importId: String
    let status: String
    let uploadUrl: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case importId = "import_id"
        case status
        case uploadUrl = "upload_url"
        case createdAt = "created_at"
    }
}

struct ImportProgress: Codable {
    let percentage: Int
    let totalFiles: Int
    let processedFiles: Int
    let totalRowsSeen: Int64
    let rowsInserted: Int64
    let rowsDeduped: Int64

    enum CodingKeys: String, CodingKey {
        case percentage
        case totalFiles = "total_files"
        case processedFiles = "processed_files"
        case totalRowsSeen = "total_rows_seen"
        case rowsInserted = "rows_inserted"
        case rowsDeduped = "rows_deduped"
    }
}

struct ImportStatus: Codable {
    let id: String
    let status: String
    let source: String
    let originalFilename: String?
    let fileSizeBytes: Int64?
    let progress: ImportProgress
    let errorMessage: String?
    let createdAt: Date
    let startedAt: Date?
    let finishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, source, progress
        case originalFilename = "original_filename"
        case fileSizeBytes = "file_size_bytes"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }

    var isComplete: Bool { status == "complete" }
    var isFailed: Bool { status == "failed" }
    var isProcessing: Bool { status == "processing" || status == "uploading" }
}

struct ImportListItem: Codable {
    let id: String
    let status: String
    let originalFilename: String?
    let rowsInserted: Int64
    let rowsDeduped: Int64
    let createdAt: Date
    let finishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case originalFilename = "original_filename"
        case rowsInserted = "rows_inserted"
        case rowsDeduped = "rows_deduped"
        case createdAt = "created_at"
        case finishedAt = "finished_at"
    }
}

struct ImportListResponse: Codable {
    let imports: [ImportListItem]
    let totalImports: Int
    let totalEventsImported: Int64
    let lastImportAt: Date?

    enum CodingKeys: String, CodingKey {
        case imports
        case totalImports = "total_imports"
        case totalEventsImported = "total_events_imported"
        case lastImportAt = "last_import_at"
    }
}

// MARK: - Import Errors

enum ImportError: LocalizedError {
    case notAuthenticated
    case invalidFileType
    case uploadFailed(String)
    case importFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please log in to import your Spotify history"
        case .invalidFileType:
            return "Please select a .zip or .json file"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .importFailed(let message):
            return "Import failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Import Service

@MainActor
class SpotifyImportService: ObservableObject {
    static let shared = SpotifyImportService()

    @Published var currentImport: ImportStatus?
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var imports: [ImportListItem] = []
    @Published var totalEventsImported: Int64 = 0

    private let baseURL = AppConfig.baseURL
    private var pollingTask: Task<Void, Never>?

    private init() {}

    // MARK: - Public Methods

    /// Import a file from a URL (from document picker)
    func importFile(from url: URL, jwt: String) async throws {
        // Validate file type
        let ext = url.pathExtension.lowercased()
        guard ext == "zip" || ext == "json" else {
            throw ImportError.invalidFileType
        }

        isUploading = true
        uploadProgress = 0

        do {
            // 1. Create import job
            let job = try await createImportJob(filename: url.lastPathComponent, jwt: jwt)

            // 2. Upload file
            uploadProgress = 0.1
            let status = try await uploadFile(importId: job.importId, fileURL: url, jwt: jwt)

            // 3. Start polling for progress
            currentImport = status
            uploadProgress = 1.0
            isUploading = false

            startPolling(importId: status.id, jwt: jwt)

        } catch {
            isUploading = false
            uploadProgress = 0
            throw error
        }
    }

    /// Get status of a specific import
    func getImportStatus(importId: String, jwt: String) async throws -> ImportStatus {
        let url = URL(string: "\(baseURL)/imports/\(importId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImportError.networkError(NSError(domain: "", code: -1))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ImportStatus.self, from: data)
    }

    /// List all imports for the user
    func listImports(jwt: String) async throws {
        let url = URL(string: "\(baseURL)/imports")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImportError.networkError(NSError(domain: "", code: -1))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let listResponse = try decoder.decode(ImportListResponse.self, from: data)

        imports = listResponse.imports
        totalEventsImported = listResponse.totalEventsImported
    }

    /// Delete an import
    func deleteImport(importId: String, jwt: String) async throws {
        let url = URL(string: "\(baseURL)/imports/\(importId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw ImportError.networkError(NSError(domain: "", code: -1))
        }

        // Remove from local list
        imports.removeAll { $0.id == importId }
    }

    /// Stop polling for import progress
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Private Methods

    private func createImportJob(filename: String?, jwt: String) async throws -> ImportJob {
        let url = URL(string: "\(baseURL)/imports")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let filename = filename {
            let body = ["filename": filename]
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw ImportError.uploadFailed("Failed to create import job")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ImportJob.self, from: data)
    }

    private func uploadFile(importId: String, fileURL: URL, jwt: String) async throws -> ImportStatus {
        let url = URL(string: "\(baseURL)/imports/\(importId)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        // Read file data
        guard fileURL.startAccessingSecurityScopedResource() else {
            throw ImportError.uploadFailed("Cannot access file")
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        let fileData = try Data(contentsOf: fileURL)

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImportError.uploadFailed("Invalid response")
        }

        if httpResponse.statusCode == 413 {
            throw ImportError.uploadFailed("File is too large (max 500MB)")
        }

        guard httpResponse.statusCode == 202 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImportError.uploadFailed(errorBody)
        }

        // Get the initial status
        return try await getImportStatus(importId: importId, jwt: jwt)
    }

    private func startPolling(importId: String, jwt: String) {
        stopPolling()

        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                    let status = try await getImportStatus(importId: importId, jwt: jwt)
                    currentImport = status

                    if status.isComplete || status.isFailed {
                        // Refresh imports list
                        try? await listImports(jwt: jwt)
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        print("Polling error: \(error)")
                    }
                    break
                }
            }
        }
    }
}

// MARK: - Supported File Types

extension SpotifyImportService {
    static var supportedContentTypes: [UTType] {
        [.zip, .json]
    }

    static var supportedExtensions: [String] {
        ["zip", "json"]
    }
}
