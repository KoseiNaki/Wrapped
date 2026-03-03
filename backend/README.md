# Wrapped API - Spotify History Import

Backend API for importing Spotify Extended Streaming History exports.

## Quick Start

```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env
# Edit .env with your database credentials

# Run migrations
npm run migrate

# Start development server
npm run dev

# Run tests
npm test
```

## API Endpoints

### Import Endpoints

#### Create Import Job

```http
POST /imports
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "filename": "my_spotify_data.zip"  // optional
}
```

Response:
```json
{
  "import_id": "uuid",
  "status": "created",
  "upload_url": "/imports/{id}/upload",
  "created_at": "2024-01-15T10:30:00Z"
}
```

#### Upload File

```http
POST /imports/{id}/upload
Authorization: Bearer <jwt_token>
Content-Type: multipart/form-data

file: <.zip or .json file>
```

Response (202 Accepted):
```json
{
  "import_id": "uuid",
  "status": "processing",
  "message": "File uploaded successfully. Processing started.",
  "check_status_url": "/imports/{id}"
}
```

#### Check Import Status

```http
GET /imports/{id}
Authorization: Bearer <jwt_token>
```

Response:
```json
{
  "id": "uuid",
  "status": "processing",  // created | uploading | processing | complete | failed
  "source": "spotify_export",
  "original_filename": "my_spotify_data.zip",
  "file_size_bytes": 52428800,
  "progress": {
    "percentage": 45,
    "total_files": 8,
    "processed_files": 4,
    "total_rows_seen": 125000,
    "rows_inserted": 120000,
    "rows_deduped": 5000
  },
  "error_message": null,
  "created_at": "2024-01-15T10:30:00Z",
  "started_at": "2024-01-15T10:30:05Z",
  "finished_at": null
}
```

#### List Imports

```http
GET /imports?limit=20&offset=0
Authorization: Bearer <jwt_token>
```

Response:
```json
{
  "imports": [
    {
      "id": "uuid",
      "status": "complete",
      "original_filename": "my_spotify_data.zip",
      "rows_inserted": 250000,
      "rows_deduped": 1500,
      "created_at": "2024-01-15T10:30:00Z",
      "finished_at": "2024-01-15T10:35:00Z"
    }
  ],
  "total_imports": 3,
  "total_events_imported": 750000,
  "last_import_at": "2024-01-15T10:35:00Z"
}
```

#### Delete Import

```http
DELETE /imports/{id}
Authorization: Bearer <jwt_token>
```

Response: 204 No Content

## Supported File Formats

### 1. StreamingHistory*.json (Simple format)

```json
[
  {
    "endTime": "2023-01-15 14:30",
    "artistName": "Taylor Swift",
    "trackName": "Anti-Hero",
    "msPlayed": 200000
  }
]
```

### 2. endsong_*.json (Extended format)

```json
[
  {
    "ts": "2023-01-15T14:30:00Z",
    "ms_played": 200000,
    "master_metadata_track_name": "Anti-Hero",
    "master_metadata_album_artist_name": "Taylor Swift",
    "master_metadata_album_album_name": "Midnights",
    "spotify_track_uri": "spotify:track:0V3wPSX9ygBnCm8psDIegu",
    "reason_start": "clickrow",
    "reason_end": "trackdone",
    "shuffle": false,
    "skipped": false,
    "offline": false,
    "incognito_mode": false,
    "platform": "iOS",
    "ip_addr_decrypted": "192.168.1.1",
    "conn_country": "US"
  }
]
```

## iOS Integration

### Swift Client Code

```swift
import Foundation

class SpotifyImportService {
    private let baseURL: URL
    private let jwt: String

    init(baseURL: URL, jwt: String) {
        self.baseURL = baseURL
        self.jwt = jwt
    }

    // 1. Create import job
    func createImport(filename: String?) async throws -> ImportJob {
        var request = URLRequest(url: baseURL.appendingPathComponent("imports"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let filename = filename {
            request.httpBody = try JSONEncoder().encode(["filename": filename])
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ImportJob.self, from: data)
    }

    // 2. Upload file
    func uploadFile(importId: String, fileURL: URL) async throws -> ImportStatus {
        let url = baseURL.appendingPathComponent("imports/\(importId)/upload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ImportStatus.self, from: data)
    }

    // 3. Check status
    func getImportStatus(importId: String) async throws -> ImportStatus {
        let url = baseURL.appendingPathComponent("imports/\(importId)")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ImportStatus.self, from: data)
    }

    // 4. Poll until complete
    func waitForCompletion(importId: String, pollInterval: TimeInterval = 2.0) async throws -> ImportStatus {
        while true {
            let status = try await getImportStatus(importId: importId)

            switch status.status {
            case "complete", "failed":
                return status
            default:
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }
}

// Models
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
```

## Deployment (Render)

1. Create a new Web Service on Render
2. Connect your repository
3. Set environment variables:
   - `DATABASE_URL`: Your Neon Postgres connection string
   - `JWT_SECRET`: A secure random string
   - `NODE_ENV`: `production`
4. Build command: `npm install && npm run build && npm run migrate`
5. Start command: `npm start`

## Architecture Notes

### Memory Efficiency

- Uses streaming JSON parser (stream-json) - never loads full files into memory
- Uses streaming ZIP reader (unzipper) - extracts files on demand
- Batch inserts (5000 rows at a time) to balance memory and speed

### Free Tier Considerations

- Background processing via `setImmediate()` - doesn't block HTTP response
- Conservative connection pool (5 max connections)
- Progress saved to database - allows monitoring even if process restarts
- File cleanup after processing

### Deduplication

Uses a unique constraint on `(user_id, played_at, track_name, artist_name, ms_played)`:
- Re-importing the same file won't create duplicates
- Same track at same time with different play duration = different event
- Handled via `ON CONFLICT DO NOTHING` for efficiency

### Error Handling

- Failed imports marked with `status: 'failed'` and `error_message`
- Partial progress saved even on failure
- Client can retry by creating a new import job
