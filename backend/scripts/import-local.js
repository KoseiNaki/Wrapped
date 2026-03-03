#!/usr/bin/env node
/**
 * Local Import Script for Spotify Streaming History
 *
 * Usage:
 *   node import-local.js <user_id> <path_to_folder_or_zip>
 *
 * Example:
 *   node import-local.js "your-user-uuid" "/path/to/spotify_data"
 *   node import-local.js "your-user-uuid" "/path/to/spotify_history.zip"
 *
 * Requires DATABASE_URL environment variable.
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

// Configuration
const BATCH_SIZE = 5000;

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

/**
 * Parse Spotify endTime format: "2023-01-15 14:30"
 */
function parseEndTime(endTime) {
  try {
    const [datePart, timePart] = endTime.split(' ');
    const [year, month, day] = datePart.split('-').map(Number);
    const [hour, minute] = timePart.split(':').map(Number);
    return new Date(Date.UTC(year, month - 1, day, hour, minute, 0));
  } catch {
    return null;
  }
}

/**
 * Parse ISO timestamp: "2023-01-15T14:30:00Z"
 */
function parseIsoTimestamp(ts) {
  try {
    const date = new Date(ts);
    return isNaN(date.getTime()) ? null : date;
  } catch {
    return null;
  }
}

/**
 * Normalize a record to our format
 */
function normalizeRecord(record) {
  // endsong format
  if (record.ts !== undefined) {
    const playedAt = parseIsoTimestamp(record.ts);
    if (!playedAt || !record.master_metadata_track_name || !record.master_metadata_album_artist_name) {
      return null;
    }
    return {
      played_at: playedAt,
      ms_played: record.ms_played || 0,
      track_name: record.master_metadata_track_name,
      artist_name: record.master_metadata_album_artist_name,
      album_name: record.master_metadata_album_album_name || null,
      spotify_track_uri: record.spotify_track_uri || null,
      platform: record.platform || null,
    };
  }

  // StreamingHistory format
  if (record.endTime !== undefined) {
    const playedAt = parseEndTime(record.endTime);
    if (!playedAt || !record.trackName || !record.artistName) {
      return null;
    }
    return {
      played_at: playedAt,
      ms_played: record.msPlayed || 0,
      track_name: record.trackName,
      artist_name: record.artistName,
      album_name: null,
      spotify_track_uri: null,
      platform: null,
    };
  }

  return null;
}

/**
 * Batch insert events
 */
async function batchInsert(client, userId, importId, events) {
  if (events.length === 0) return { inserted: 0, deduped: 0 };

  const values = [];
  const placeholders = [];
  let paramIndex = 1;

  for (const event of events) {
    placeholders.push(
      `($${paramIndex}, $${paramIndex + 1}, $${paramIndex + 2}, $${paramIndex + 3}, ` +
      `$${paramIndex + 4}, $${paramIndex + 5}, $${paramIndex + 6}, $${paramIndex + 7}, $${paramIndex + 8})`
    );
    values.push(
      userId,
      importId,
      event.played_at.toISOString(),
      event.ms_played,
      event.track_name,
      event.artist_name,
      event.album_name,
      event.spotify_track_uri,
      event.platform
    );
    paramIndex += 9;
  }

  const sql = `
    INSERT INTO listening_events (
      user_id, import_id, played_at, ms_played, track_name, artist_name,
      album_name, spotify_track_uri, platform
    ) VALUES ${placeholders.join(', ')}
    ON CONFLICT (user_id, played_at, track_name, artist_name, ms_played)
    DO NOTHING
    RETURNING id
  `;

  const result = await client.query(sql, values);
  const inserted = result.rowCount || 0;
  return { inserted, deduped: events.length - inserted };
}

/**
 * Process a single JSON file
 */
async function processJsonFile(client, userId, importId, filePath) {
  console.log(`  Processing: ${path.basename(filePath)}`);

  const content = fs.readFileSync(filePath, 'utf-8');
  const records = JSON.parse(content);

  let totalSeen = 0;
  let totalInserted = 0;
  let totalDeduped = 0;
  let batch = [];

  for (const record of records) {
    totalSeen++;
    const event = normalizeRecord(record);

    if (event) {
      batch.push(event);
    }

    if (batch.length >= BATCH_SIZE) {
      const { inserted, deduped } = await batchInsert(client, userId, importId, batch);
      totalInserted += inserted;
      totalDeduped += deduped;
      batch = [];
      process.stdout.write(`    ${totalSeen} records processed...\r`);
    }
  }

  // Flush remaining
  if (batch.length > 0) {
    const { inserted, deduped } = await batchInsert(client, userId, importId, batch);
    totalInserted += inserted;
    totalDeduped += deduped;
  }

  console.log(`    ${totalSeen} records: ${totalInserted} inserted, ${totalDeduped} duplicates`);
  return { totalSeen, inserted: totalInserted, deduped: totalDeduped };
}

/**
 * Main import function
 */
async function runImport(userId, inputPath) {
  console.log('\n🎵 Spotify History Import\n');
  console.log(`User ID: ${userId}`);
  console.log(`Input: ${inputPath}\n`);

  // Find JSON files
  let jsonFiles = [];
  const stat = fs.statSync(inputPath);

  if (stat.isDirectory()) {
    const files = fs.readdirSync(inputPath);
    jsonFiles = files
      .filter(f => f.toLowerCase().includes('streaming') && f.endsWith('.json'))
      .map(f => path.join(inputPath, f))
      .sort();
  } else if (inputPath.endsWith('.json')) {
    jsonFiles = [inputPath];
  } else if (inputPath.endsWith('.zip')) {
    console.log('❌ ZIP files not supported in this script. Please unzip first.');
    console.log('   Run: unzip your_file.zip -d ./spotify_data');
    process.exit(1);
  }

  if (jsonFiles.length === 0) {
    console.log('❌ No JSON files found');
    process.exit(1);
  }

  console.log(`Found ${jsonFiles.length} JSON file(s)\n`);

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Create import record
    const importResult = await client.query(
      `INSERT INTO imports (user_id, status, source, total_files, original_filename)
       VALUES ($1, 'processing', 'spotify_export', $2, $3)
       RETURNING id`,
      [userId, jsonFiles.length, path.basename(inputPath)]
    );
    const importId = importResult.rows[0].id;
    console.log(`Import ID: ${importId}\n`);

    let grandTotalSeen = 0;
    let grandTotalInserted = 0;
    let grandTotalDeduped = 0;

    for (let i = 0; i < jsonFiles.length; i++) {
      const { totalSeen, inserted, deduped } = await processJsonFile(
        client, userId, importId, jsonFiles[i]
      );
      grandTotalSeen += totalSeen;
      grandTotalInserted += inserted;
      grandTotalDeduped += deduped;

      // Update progress
      await client.query(
        `UPDATE imports SET
           processed_files = $1,
           total_rows_seen = $2,
           rows_inserted = $3,
           rows_deduped = $4
         WHERE id = $5`,
        [i + 1, grandTotalSeen, grandTotalInserted, grandTotalDeduped, importId]
      );
    }

    // Mark complete
    await client.query(
      `UPDATE imports SET status = 'complete', finished_at = NOW() WHERE id = $1`,
      [importId]
    );

    await client.query('COMMIT');

    console.log('\n✅ Import Complete!\n');
    console.log(`   Total records seen: ${grandTotalSeen.toLocaleString()}`);
    console.log(`   Records inserted:   ${grandTotalInserted.toLocaleString()}`);
    console.log(`   Duplicates skipped: ${grandTotalDeduped.toLocaleString()}`);
    console.log('');

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Import failed:', error.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

// CLI
const args = process.argv.slice(2);

if (args.length < 2) {
  console.log(`
Usage: DATABASE_URL=<url> node import-local.js <user_id> <path>

Arguments:
  user_id   Your user UUID from the database
  path      Path to folder containing JSON files, or a single JSON file

Example:
  DATABASE_URL="postgresql://..." node import-local.js \\
    "550e8400-e29b-41d4-a716-446655440000" \\
    "/Users/you/Downloads/spotify_data"
`);
  process.exit(1);
}

if (!process.env.DATABASE_URL) {
  console.log('❌ DATABASE_URL environment variable is required');
  process.exit(1);
}

runImport(args[0], args[1]);
