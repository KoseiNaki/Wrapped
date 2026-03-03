#!/usr/bin/env node
/**
 * Backfill artist names from Spotify Extended Streaming History
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

function extractTrackId(uri) {
  if (!uri) return null;
  const parts = uri.split(':');
  return parts.length === 3 ? parts[2] : null;
}

async function backfillArtists(folderPath) {
  console.log('\n🎤 Backfill Artist Names\n');
  console.log(`Folder: ${folderPath}\n`);

  const files = fs.readdirSync(folderPath)
    .filter(f => f.includes('Streaming_History') && f.endsWith('.json') && f.includes('Audio'))
    .sort()
    .map(f => path.join(folderPath, f));

  console.log(`Found ${files.length} files\n`);

  // Collect unique track -> artist mappings
  const trackArtists = new Map();

  for (const file of files) {
    const filename = path.basename(file);
    console.log(`Reading: ${filename}`);

    const content = fs.readFileSync(file, 'utf-8');
    const records = JSON.parse(content);

    for (const record of records) {
      const trackId = extractTrackId(record.spotify_track_uri);
      if (!trackId) continue;

      const artistName = record.master_metadata_album_artist_name;
      if (artistName && !trackArtists.has(trackId)) {
        trackArtists.set(trackId, artistName);
      }
    }
  }

  console.log(`\nFound ${trackArtists.size} unique track-artist mappings\n`);

  // Update tracks in batches
  const client = await pool.connect();
  let updated = 0;

  try {
    const entries = Array.from(trackArtists.entries());
    const BATCH_SIZE = 500;

    for (let i = 0; i < entries.length; i += BATCH_SIZE) {
      const batch = entries.slice(i, i + BATCH_SIZE);

      // Build UPDATE query with CASE
      const cases = batch.map(([id, artist]) =>
        `WHEN '${id.replace(/'/g, "''")}' THEN '${artist.replace(/'/g, "''")}'`
      ).join(' ');

      const ids = batch.map(([id]) => `'${id.replace(/'/g, "''")}'`).join(', ');

      const sql = `
        UPDATE tracks
        SET artist_name = CASE id ${cases} END
        WHERE id IN (${ids}) AND artist_name IS NULL
      `;

      const result = await client.query(sql);
      updated += result.rowCount || 0;

      process.stdout.write(`Updated ${updated}/${trackArtists.size} tracks...\r`);
    }

    console.log(`\n\n✅ Updated ${updated} tracks with artist names\n`);

  } finally {
    client.release();
    await pool.end();
  }
}

const folderPath = process.argv[2] || '/Users/naki/Spotify Extended Streaming History';

if (!process.env.DATABASE_URL) {
  console.log('❌ DATABASE_URL required');
  process.exit(1);
}

backfillArtists(folderPath);
