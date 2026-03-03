/**
 * Import Service
 *
 * Handles Spotify streaming history imports with:
 * - Streaming ZIP/JSON parsing (memory-efficient)
 * - Batch database inserts
 * - Idempotent deduplication
 * - Progress tracking
 * - Resumable processing
 */

import { query, getClient } from '../config/database';
import { PoolClient } from 'pg';
import { v4 as uuidv4 } from 'uuid';
import fs from 'fs';
import path from 'path';
import { Readable } from 'stream';
import unzipper from 'unzipper';
import { parser } from 'stream-json';
import { streamArray } from 'stream-json/streamers/StreamArray';
import { chain } from 'stream-chain';

// Types
export interface Import {
  id: string;
  user_id: string;
  status: 'created' | 'uploading' | 'processing' | 'complete' | 'failed';
  source: string;
  original_filename: string | null;
  file_size_bytes: number | null;
  total_files: number;
  processed_files: number;
  total_rows_seen: number;
  rows_inserted: number;
  rows_deduped: number;
  current_file_index: number;
  current_file_offset: number;
  error_message: string | null;
  created_at: Date;
  started_at: Date | null;
  finished_at: Date | null;
  updated_at: Date;
}

export interface ListeningEvent {
  played_at: Date;
  ms_played: number;
  track_name: string;
  artist_name: string;
  album_name?: string;
  spotify_track_uri?: string;
  spotify_artist_uri?: string;
  spotify_album_uri?: string;
  reason_start?: string;
  reason_end?: string;
  shuffle?: boolean;
  skipped?: boolean;
  offline?: boolean;
  incognito_mode?: boolean;
  platform?: string;
  ip_addr?: string;
  country?: string;
}

// Spotify export format types
interface StreamingHistoryRecord {
  endTime?: string;      // "2023-01-15 14:30"
  artistName?: string;
  trackName?: string;
  msPlayed?: number;
}

interface EndsongRecord {
  ts?: string;                    // ISO 8601: "2023-01-15T14:30:00Z"
  ms_played?: number;
  master_metadata_track_name?: string;
  master_metadata_album_artist_name?: string;
  master_metadata_album_album_name?: string;
  spotify_track_uri?: string;
  reason_start?: string;
  reason_end?: string;
  shuffle?: boolean;
  skipped?: boolean;
  offline?: boolean;
  incognito_mode?: boolean;
  platform?: string;
  ip_addr_decrypted?: string;
  conn_country?: string;
}

const BATCH_SIZE = 5000; // Rows per batch insert
const CHUNK_SIZE = 10000; // Rows to process before yielding (for chunked processing)

/**
 * Create a new import job
 */
export async function createImport(userId: string, filename?: string): Promise<Import> {
  const { rows } = await query<Import>(
    `INSERT INTO imports (user_id, original_filename, status)
     VALUES ($1, $2, 'created')
     RETURNING *`,
    [userId, filename || null]
  );
  return rows[0];
}

/**
 * Get import by ID (with user verification)
 */
export async function getImport(importId: string, userId: string): Promise<Import | null> {
  const { rows } = await query<Import>(
    'SELECT * FROM imports WHERE id = $1 AND user_id = $2',
    [importId, userId]
  );
  return rows[0] || null;
}

/**
 * List imports for a user
 */
export async function listImports(userId: string, limit = 20, offset = 0): Promise<Import[]> {
  const { rows } = await query<Import>(
    `SELECT * FROM imports
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT $2 OFFSET $3`,
    [userId, limit, offset]
  );
  return rows;
}

/**
 * Update import status and progress
 */
export async function updateImport(
  importId: string,
  updates: Partial<Pick<Import,
    'status' | 'total_files' | 'processed_files' | 'total_rows_seen' |
    'rows_inserted' | 'rows_deduped' | 'current_file_index' |
    'current_file_offset' | 'error_message' | 'started_at' | 'finished_at' |
    'file_size_bytes'
  >>
): Promise<Import | null> {
  const fields: string[] = [];
  const values: any[] = [];
  let paramIndex = 1;

  for (const [key, value] of Object.entries(updates)) {
    if (value !== undefined) {
      fields.push(`${key} = $${paramIndex}`);
      values.push(value);
      paramIndex++;
    }
  }

  if (fields.length === 0) return null;

  values.push(importId);
  const { rows } = await query<Import>(
    `UPDATE imports SET ${fields.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
    values
  );
  return rows[0] || null;
}

/**
 * Parse a Spotify endTime string to Date
 * Format: "2023-01-15 14:30" (local time, assumed UTC)
 */
function parseEndTime(endTime: string): Date | null {
  try {
    // Format: "YYYY-MM-DD HH:mm"
    const [datePart, timePart] = endTime.split(' ');
    if (!datePart || !timePart) return null;

    const [year, month, day] = datePart.split('-').map(Number);
    const [hour, minute] = timePart.split(':').map(Number);

    return new Date(Date.UTC(year, month - 1, day, hour, minute, 0));
  } catch {
    return null;
  }
}

/**
 * Parse an ISO 8601 timestamp
 */
function parseIsoTimestamp(ts: string): Date | null {
  try {
    const date = new Date(ts);
    return isNaN(date.getTime()) ? null : date;
  } catch {
    return null;
  }
}

/**
 * Normalize a StreamingHistory record to our format
 */
function normalizeStreamingHistory(record: StreamingHistoryRecord): ListeningEvent | null {
  if (!record.endTime || !record.trackName || !record.artistName) {
    return null;
  }

  const playedAt = parseEndTime(record.endTime);
  if (!playedAt) return null;

  return {
    played_at: playedAt,
    ms_played: record.msPlayed || 0,
    track_name: record.trackName,
    artist_name: record.artistName,
  };
}

/**
 * Normalize an endsong record to our format
 */
function normalizeEndsong(record: EndsongRecord): ListeningEvent | null {
  if (!record.ts || !record.master_metadata_track_name || !record.master_metadata_album_artist_name) {
    return null;
  }

  const playedAt = parseIsoTimestamp(record.ts);
  if (!playedAt) return null;

  return {
    played_at: playedAt,
    ms_played: record.ms_played || 0,
    track_name: record.master_metadata_track_name,
    artist_name: record.master_metadata_album_artist_name,
    album_name: record.master_metadata_album_album_name,
    spotify_track_uri: record.spotify_track_uri,
    reason_start: record.reason_start,
    reason_end: record.reason_end,
    shuffle: record.shuffle,
    skipped: record.skipped,
    offline: record.offline,
    incognito_mode: record.incognito_mode,
    platform: record.platform,
    ip_addr: record.ip_addr_decrypted,
    country: record.conn_country,
  };
}

/**
 * Detect record format and normalize
 */
function normalizeRecord(record: any): ListeningEvent | null {
  // Endsong format has 'ts' field
  if (record.ts !== undefined) {
    return normalizeEndsong(record as EndsongRecord);
  }
  // StreamingHistory format has 'endTime' field
  if (record.endTime !== undefined) {
    return normalizeStreamingHistory(record as StreamingHistoryRecord);
  }
  return null;
}

/**
 * Batch insert events with ON CONFLICT for deduplication
 */
async function batchInsertEvents(
  client: PoolClient,
  userId: string,
  importId: string,
  events: ListeningEvent[]
): Promise<{ inserted: number; deduped: number }> {
  if (events.length === 0) return { inserted: 0, deduped: 0 };

  // Build the VALUES clause
  const values: any[] = [];
  const valuePlaceholders: string[] = [];
  let paramIndex = 1;

  for (const event of events) {
    valuePlaceholders.push(
      `($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, ` +
      `$${paramIndex + 4}, $${paramIndex + 5}, $${paramIndex + 6}, $${paramIndex + 7}, ` +
      `$${paramIndex + 8}, $${paramIndex + 9}, $${paramIndex + 10}, $${paramIndex + 11}, ` +
      `$${paramIndex + 12}, $${paramIndex + 13}, $${paramIndex + 14}, $${paramIndex + 15}, ` +
      `$${paramIndex + 16})`
    );

    values.push(
      userId,
      importId,
      event.played_at.toISOString(),
      event.ms_played,
      event.track_name,
      event.artist_name,
      event.album_name || null,
      event.spotify_track_uri || null,
      event.spotify_artist_uri || null,
      event.spotify_album_uri || null,
      event.reason_start || null,
      event.reason_end || null,
      event.shuffle ?? null,
      event.skipped ?? null,
      event.offline ?? null,
      event.incognito_mode ?? null,
      event.platform || null
    );

    paramIndex += 17;
  }

  const sql = `
    INSERT INTO listening_events (
      user_id, import_id, played_at, ms_played, track_name, artist_name,
      album_name, spotify_track_uri, spotify_artist_uri, spotify_album_uri,
      reason_start, reason_end, shuffle, skipped, offline, incognito_mode, platform
    ) VALUES ${valuePlaceholders.join(', ')}
    ON CONFLICT (user_id, played_at, track_name, artist_name, ms_played)
    DO NOTHING
    RETURNING id
  `;

  const result = await client.query(sql, values);
  const inserted = result.rowCount || 0;
  const deduped = events.length - inserted;

  return { inserted, deduped };
}

/**
 * Process a JSON stream of listening events
 */
async function processJsonStream(
  stream: Readable,
  userId: string,
  importId: string,
  onProgress: (seen: number, inserted: number, deduped: number) => Promise<void>
): Promise<{ totalSeen: number; inserted: number; deduped: number }> {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    let totalSeen = 0;
    let totalInserted = 0;
    let totalDeduped = 0;
    let batch: ListeningEvent[] = [];

    const pipeline = chain([
      stream,
      parser(),
      streamArray(),
    ]);

    for await (const { value } of pipeline) {
      totalSeen++;

      const event = normalizeRecord(value);
      if (event) {
        batch.push(event);
      }

      // Flush batch when full
      if (batch.length >= BATCH_SIZE) {
        const { inserted, deduped } = await batchInsertEvents(client, userId, importId, batch);
        totalInserted += inserted;
        totalDeduped += deduped;
        batch = [];

        // Report progress
        await onProgress(totalSeen, totalInserted, totalDeduped);
      }

      // Yield to event loop periodically to prevent blocking
      if (totalSeen % 1000 === 0) {
        await new Promise(resolve => setImmediate(resolve));
      }
    }

    // Flush remaining batch
    if (batch.length > 0) {
      const { inserted, deduped } = await batchInsertEvents(client, userId, importId, batch);
      totalInserted += inserted;
      totalDeduped += deduped;
    }

    await client.query('COMMIT');
    return { totalSeen, inserted: totalInserted, deduped: totalDeduped };

  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Process a single JSON file
 */
async function processJsonFile(
  filePath: string,
  userId: string,
  importId: string,
  onProgress: (seen: number, inserted: number, deduped: number) => Promise<void>
): Promise<{ totalSeen: number; inserted: number; deduped: number }> {
  const stream = fs.createReadStream(filePath, { encoding: 'utf8' });
  return processJsonStream(stream, userId, importId, onProgress);
}

/**
 * Get list of JSON files from a ZIP archive
 */
async function getZipJsonEntries(zipPath: string): Promise<string[]> {
  const entries: string[] = [];

  const directory = await unzipper.Open.file(zipPath);
  for (const entry of directory.files) {
    const name = entry.path.toLowerCase();
    if (
      (name.includes('streaminghistory') || name.includes('endsong')) &&
      name.endsWith('.json') &&
      !name.startsWith('__macosx') &&
      !name.includes('._')
    ) {
      entries.push(entry.path);
    }
  }

  return entries.sort();
}

/**
 * Process a ZIP file containing JSON files
 */
export async function processZipFile(
  zipPath: string,
  userId: string,
  importId: string
): Promise<void> {
  // Get list of JSON files
  const jsonEntries = await getZipJsonEntries(zipPath);

  if (jsonEntries.length === 0) {
    throw new Error('No valid JSON files found in ZIP archive');
  }

  await updateImport(importId, {
    status: 'processing',
    started_at: new Date(),
    total_files: jsonEntries.length,
  });

  let totalSeen = 0;
  let totalInserted = 0;
  let totalDeduped = 0;

  const directory = await unzipper.Open.file(zipPath);

  for (let i = 0; i < jsonEntries.length; i++) {
    const entryPath = jsonEntries[i];
    const entry = directory.files.find(f => f.path === entryPath);

    if (!entry) continue;

    console.log(`Processing file ${i + 1}/${jsonEntries.length}: ${entryPath}`);

    try {
      const stream = entry.stream() as unknown as Readable;

      const result = await processJsonStream(
        stream,
        userId,
        importId,
        async (seen, inserted, deduped) => {
          // Update progress periodically
          await updateImport(importId, {
            total_rows_seen: totalSeen + seen,
            rows_inserted: totalInserted + inserted,
            rows_deduped: totalDeduped + deduped,
          });
        }
      );

      totalSeen += result.totalSeen;
      totalInserted += result.inserted;
      totalDeduped += result.deduped;

      await updateImport(importId, {
        processed_files: i + 1,
        total_rows_seen: totalSeen,
        rows_inserted: totalInserted,
        rows_deduped: totalDeduped,
        current_file_index: i + 1,
      });

    } catch (error) {
      console.error(`Error processing ${entryPath}:`, error);
      throw new Error(`Failed to process ${entryPath}: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  await updateImport(importId, {
    status: 'complete',
    finished_at: new Date(),
    total_rows_seen: totalSeen,
    rows_inserted: totalInserted,
    rows_deduped: totalDeduped,
  });
}

/**
 * Process a single JSON file upload
 */
export async function processSingleJsonFile(
  filePath: string,
  userId: string,
  importId: string
): Promise<void> {
  await updateImport(importId, {
    status: 'processing',
    started_at: new Date(),
    total_files: 1,
  });

  try {
    const result = await processJsonFile(
      filePath,
      userId,
      importId,
      async (seen, inserted, deduped) => {
        await updateImport(importId, {
          total_rows_seen: seen,
          rows_inserted: inserted,
          rows_deduped: deduped,
        });
      }
    );

    await updateImport(importId, {
      status: 'complete',
      finished_at: new Date(),
      processed_files: 1,
      total_rows_seen: result.totalSeen,
      rows_inserted: result.inserted,
      rows_deduped: result.deduped,
    });

  } catch (error) {
    throw error;
  }
}

/**
 * Start processing an uploaded file (ZIP or JSON)
 * This is designed to be called in a "fire and forget" manner
 */
export async function startImportProcessing(
  filePath: string,
  userId: string,
  importId: string,
  isZip: boolean
): Promise<void> {
  try {
    if (isZip) {
      await processZipFile(filePath, userId, importId);
    } else {
      await processSingleJsonFile(filePath, userId, importId);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error(`Import ${importId} failed:`, message);

    await updateImport(importId, {
      status: 'failed',
      error_message: message,
      finished_at: new Date(),
    });
  } finally {
    // Clean up uploaded file
    try {
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    } catch (e) {
      console.error('Failed to clean up file:', e);
    }
  }
}

/**
 * Get import statistics for a user
 */
export async function getImportStats(userId: string): Promise<{
  totalImports: number;
  totalEventsImported: number;
  lastImportAt: Date | null;
}> {
  const { rows } = await query<{
    total_imports: string;
    total_events: string;
    last_import_at: Date | null;
  }>(
    `SELECT
       COUNT(*) as total_imports,
       COALESCE(SUM(rows_inserted), 0) as total_events,
       MAX(finished_at) as last_import_at
     FROM imports
     WHERE user_id = $1 AND status = 'complete'`,
    [userId]
  );

  return {
    totalImports: parseInt(rows[0]?.total_imports || '0', 10),
    totalEventsImported: parseInt(rows[0]?.total_events || '0', 10),
    lastImportAt: rows[0]?.last_import_at || null,
  };
}
