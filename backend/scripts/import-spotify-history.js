#!/usr/bin/env node
/**
 * Import Spotify Extended Streaming History
 *
 * Imports Spotify export data into the existing schema:
 * - Creates tracks if they don't exist
 * - Creates listening_events with proper track references
 * - Handles deduplication
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const BATCH_SIZE = 1000;
const USER_ID = '50656227-0cba-48dc-ad6b-06d255e3c28d';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

/**
 * Extract track ID from spotify_track_uri
 * "spotify:track:6NIJqFHB5cHAn064JCP7Li" → "6NIJqFHB5cHAn064JCP7Li"
 */
function extractTrackId(uri) {
  if (!uri) return null;
  const parts = uri.split(':');
  return parts.length === 3 ? parts[2] : null;
}

/**
 * Extract album ID from spotify_album_uri if present
 */
function extractAlbumId(uri) {
  if (!uri) return null;
  const parts = uri.split(':');
  return parts.length === 3 ? parts[2] : null;
}

/**
 * Process a batch of records
 */
async function processBatch(client, records, stats) {
  // Collect unique tracks
  const tracksToInsert = new Map();

  for (const record of records) {
    const trackId = extractTrackId(record.spotify_track_uri);
    if (!trackId || !record.master_metadata_track_name) continue;

    if (!tracksToInsert.has(trackId)) {
      tracksToInsert.set(trackId, {
        id: trackId,
        name: record.master_metadata_track_name,
        album_name: record.master_metadata_album_album_name,
        artist_name: record.master_metadata_album_artist_name,
      });
    }
  }

  // Insert tracks (ON CONFLICT DO NOTHING)
  if (tracksToInsert.size > 0) {
    const trackValues = [];
    const trackPlaceholders = [];
    let idx = 1;

    for (const track of tracksToInsert.values()) {
      trackPlaceholders.push(`($${idx}, $${idx + 1})`);
      trackValues.push(track.id, track.name);
      idx += 2;
    }

    await client.query(`
      INSERT INTO tracks (id, name)
      VALUES ${trackPlaceholders.join(', ')}
      ON CONFLICT (id) DO NOTHING
    `, trackValues);

    stats.tracksCreated += tracksToInsert.size;
  }

  // Insert listening events
  const eventValues = [];
  const eventPlaceholders = [];
  let idx = 1;

  for (const record of records) {
    const trackId = extractTrackId(record.spotify_track_uri);
    if (!trackId || !record.ts) continue;

    const playedAt = new Date(record.ts);
    if (isNaN(playedAt.getTime())) continue;

    const playedAtMs = playedAt.getTime().toString();
    const eventId = `${USER_ID}:${trackId}:${playedAtMs}`;

    eventPlaceholders.push(`($${idx}, $${idx + 1}, $${idx + 2}, $${idx + 3}, $${idx + 4})`);
    eventValues.push(eventId, USER_ID, trackId, playedAt.toISOString(), playedAtMs);
    idx += 5;

    stats.totalSeen++;
  }

  if (eventValues.length > 0) {
    const result = await client.query(`
      INSERT INTO listening_events (id, user_id, track_id, played_at, played_at_ms)
      VALUES ${eventPlaceholders.join(', ')}
      ON CONFLICT (id) DO NOTHING
      RETURNING id
    `, eventValues);

    stats.inserted += result.rowCount || 0;
    stats.deduped += (eventValues.length / 5) - (result.rowCount || 0);
  }
}

/**
 * Process a single JSON file
 */
async function processFile(client, filePath, stats) {
  const filename = path.basename(filePath);
  console.log(`  Processing: ${filename}`);

  const content = fs.readFileSync(filePath, 'utf-8');
  const records = JSON.parse(content);

  // Filter to audio tracks only (skip podcasts, etc.)
  const audioRecords = records.filter(r =>
    r.spotify_track_uri &&
    r.master_metadata_track_name &&
    r.ms_played > 0
  );

  console.log(`    ${records.length} total records, ${audioRecords.length} audio tracks`);

  // Process in batches
  for (let i = 0; i < audioRecords.length; i += BATCH_SIZE) {
    const batch = audioRecords.slice(i, i + BATCH_SIZE);
    await processBatch(client, batch, stats);
    process.stdout.write(`    Processed ${Math.min(i + BATCH_SIZE, audioRecords.length)}/${audioRecords.length}\r`);
  }

  console.log(`    Done: ${stats.inserted} inserted so far`);
}

/**
 * Main import function
 */
async function runImport(folderPath) {
  console.log('\n🎵 Spotify History Import\n');
  console.log(`User: ${USER_ID}`);
  console.log(`Folder: ${folderPath}\n`);

  // Find JSON files
  const files = fs.readdirSync(folderPath)
    .filter(f => f.includes('Streaming_History') && f.endsWith('.json') && f.includes('Audio'))
    .sort()
    .map(f => path.join(folderPath, f));

  console.log(`Found ${files.length} audio history files\n`);

  const stats = {
    totalSeen: 0,
    inserted: 0,
    deduped: 0,
    tracksCreated: 0,
  };

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Create import record
    const importResult = await client.query(`
      INSERT INTO imports (user_id, status, source, total_files, original_filename)
      VALUES ($1, 'processing', 'spotify_export', $2, $3)
      RETURNING id
    `, [USER_ID, files.length, 'Spotify Extended Streaming History']);

    const importId = importResult.rows[0].id;
    console.log(`Import ID: ${importId}\n`);

    // Process each file
    for (let i = 0; i < files.length; i++) {
      await processFile(client, files[i], stats);

      // Update progress
      await client.query(`
        UPDATE imports SET
          processed_files = $1,
          total_rows_seen = $2,
          rows_inserted = $3,
          rows_deduped = $4
        WHERE id = $5
      `, [i + 1, stats.totalSeen, stats.inserted, stats.deduped, importId]);
    }

    // Mark complete
    await client.query(`
      UPDATE imports SET status = 'complete', finished_at = NOW() WHERE id = $1
    `, [importId]);

    // Update user stats
    await client.query(`
      UPDATE users SET
        total_tracks_listened = (SELECT COUNT(*) FROM listening_events WHERE user_id = $1),
        total_listening_time_ms = 0
      WHERE id = $1
    `, [USER_ID]);

    await client.query('COMMIT');

    console.log('\n✅ Import Complete!\n');
    console.log(`   Total records seen:  ${stats.totalSeen.toLocaleString()}`);
    console.log(`   Events inserted:     ${stats.inserted.toLocaleString()}`);
    console.log(`   Duplicates skipped:  ${stats.deduped.toLocaleString()}`);
    console.log(`   Tracks created:      ${stats.tracksCreated.toLocaleString()}`);
    console.log('');

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Import failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

// Run
const folderPath = process.argv[2] || '/Users/naki/Spotify Extended Streaming History';

if (!process.env.DATABASE_URL) {
  console.log('❌ DATABASE_URL environment variable required');
  process.exit(1);
}

runImport(folderPath);
