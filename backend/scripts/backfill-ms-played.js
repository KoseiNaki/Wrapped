#!/usr/bin/env node
/**
 * Backfill ms_played column from Spotify Extended Streaming History
 *
 * Updates listening_events with ms_played values from the original export files.
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
 */
function extractTrackId(uri) {
  if (!uri) return null;
  const parts = uri.split(':');
  return parts.length === 3 ? parts[2] : null;
}

/**
 * Process a batch of updates
 */
async function processBatch(client, updates, stats) {
  if (updates.length === 0) return;

  // Build a single UPDATE query using CASE WHEN
  // UPDATE listening_events SET ms_played = CASE id WHEN 'id1' THEN ms1 WHEN 'id2' THEN ms2 END WHERE id IN (...)

  const ids = [];
  const cases = [];

  for (const update of updates) {
    ids.push(`'${update.eventId}'`);
    cases.push(`WHEN '${update.eventId}' THEN ${update.msPlayed}`);
  }

  const sql = `
    UPDATE listening_events
    SET ms_played = CASE id ${cases.join(' ')} END
    WHERE id IN (${ids.join(', ')})
  `;

  const result = await client.query(sql);
  stats.updated += result.rowCount || 0;
}

/**
 * Process a single JSON file
 */
async function processFile(client, filePath, stats) {
  const filename = path.basename(filePath);
  console.log(`  Processing: ${filename}`);

  const content = fs.readFileSync(filePath, 'utf-8');
  const records = JSON.parse(content);

  // Filter to audio tracks with ms_played
  const audioRecords = records.filter(r =>
    r.spotify_track_uri &&
    r.master_metadata_track_name &&
    r.ms_played !== undefined
  );

  console.log(`    ${records.length} total records, ${audioRecords.length} with ms_played`);

  let updates = [];

  for (const record of audioRecords) {
    const trackId = extractTrackId(record.spotify_track_uri);
    if (!trackId || !record.ts) continue;

    const playedAt = new Date(record.ts);
    if (isNaN(playedAt.getTime())) continue;

    const playedAtMs = playedAt.getTime().toString();
    const eventId = `${USER_ID}:${trackId}:${playedAtMs}`;

    updates.push({
      eventId,
      msPlayed: record.ms_played
    });

    stats.totalSeen++;

    if (updates.length >= BATCH_SIZE) {
      await processBatch(client, updates, stats);
      updates = [];
      process.stdout.write(`    Processed ${stats.totalSeen}...\\r`);
    }
  }

  // Flush remaining
  if (updates.length > 0) {
    await processBatch(client, updates, stats);
  }

  console.log(`    Done: ${stats.updated} updated so far`);
}

/**
 * Main backfill function
 */
async function runBackfill(folderPath) {
  console.log('\n🔄 Backfill ms_played\n');
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
    updated: 0,
  };

  const client = await pool.connect();

  try {
    // Process each file
    for (const file of files) {
      await processFile(client, file, stats);
    }

    console.log('\n✅ Backfill Complete!\n');
    console.log(`   Total records processed: ${stats.totalSeen.toLocaleString()}`);
    console.log(`   Events updated:          ${stats.updated.toLocaleString()}`);
    console.log('');

  } catch (error) {
    console.error('\n❌ Backfill failed:', error.message);
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

runBackfill(folderPath);
