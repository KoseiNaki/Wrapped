#!/usr/bin/env node
/**
 * Fetch artist genres from Spotify API using Client Credentials flow.
 * Finds top artists by play count that are missing from the artists table,
 * searches Spotify for each, and upserts with genre data.
 *
 * Usage: DATABASE_URL=... SPOTIFY_CLIENT_ID=... SPOTIFY_CLIENT_SECRET=... node fetch-artist-genres.js
 */

const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

const CLIENT_ID = process.env.SPOTIFY_CLIENT_ID;
const CLIENT_SECRET = process.env.SPOTIFY_CLIENT_SECRET;

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error('Missing SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET');
  process.exit(1);
}

async function getClientCredentialsToken() {
  const credentials = Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString('base64');
  const res = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  if (!res.ok) throw new Error(`Token error: ${res.status} ${await res.text()}`);
  const data = await res.json();
  return data.access_token;
}

// Search for artist by name to get Spotify ID (search does NOT return genres)
async function searchArtistId(name, token) {
  const url = `https://api.spotify.com/v1/search?q=${encodeURIComponent(name)}&type=artist&limit=1`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` }, signal: controller.signal });
    clearTimeout(timeout);
    if (!res.ok) {
      if (res.status === 429) {
        const retry = parseInt(res.headers.get('Retry-After') || '2', 10);
        await new Promise(r => setTimeout(r, retry * 1000));
        return searchArtistId(name, token);
      }
      throw new Error(`Search error for "${name}": ${res.status}`);
    }
    const data = await res.json();
    const artist = data.artists?.items?.[0];
    if (!artist) return null;
    return { id: artist.id, name: artist.name };
  } catch (err) {
    clearTimeout(timeout);
    if (err.name === 'AbortError') throw new Error(`Timeout searching for "${name}"`);
    throw err;
  }
}

// Fetch up to 50 artists at once by ID — this endpoint returns genres
async function fetchArtistsByIds(ids, token) {
  const url = `https://api.spotify.com/v1/artists?ids=${ids.join(',')}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` }, signal: controller.signal });
    clearTimeout(timeout);
    if (!res.ok) {
      if (res.status === 429) {
        const retry = parseInt(res.headers.get('Retry-After') || '2', 10);
        await new Promise(r => setTimeout(r, retry * 1000));
        return fetchArtistsByIds(ids, token);
      }
      throw new Error(`Artists batch error: ${res.status}`);
    }
    const data = await res.json();
    return data.artists || [];
  } catch (err) {
    clearTimeout(timeout);
    if (err.name === 'AbortError') throw new Error('Timeout fetching artist batch');
    throw err;
  }
}

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function main() {
  console.log('\n🎤 Fetch Artist Genres from Spotify\n');

  // Get top artists by play count that are missing genre data
  const { rows: topArtists } = await pool.query(`
    SELECT
      t.artist_name AS name,
      COUNT(*) AS play_count
    FROM listening_events le
    JOIN tracks t ON le.track_id = t.id
    WHERE t.artist_name IS NOT NULL
    GROUP BY t.artist_name
    ORDER BY play_count DESC
    LIMIT 500
  `);

  console.log(`Found ${topArtists.length} top artists to process\n`);

  // Check which already have genre data in artists table (by name match)
  const { rows: existing } = await pool.query(`
    SELECT name FROM artists WHERE genres IS NOT NULL AND genres != '[]'
  `);
  const existingGenres = new Set(existing.map(r => r.name.toLowerCase()));
  console.log(`${existing.length} artists already have genres\n`);

  // Also skip artists we already found Spotify IDs for (even if genres empty)
  const { rows: existingArtists } = await pool.query(`
    SELECT name FROM artists
  `);
  const existingNames = new Set(existingArtists.map(r => r.name.toLowerCase()));

  const toFetch = topArtists.filter(a => !existingGenres.has(a.name.toLowerCase()));
  console.log(`Fetching genres for ${toFetch.length} artists...\n`);

  const token = await getClientCredentialsToken();
  console.log('Got Spotify access token\n');

  let successCount = 0;
  let noResultCount = 0;
  let noGenreCount = 0;

  // Phase 1: Search for Spotify IDs (search endpoint doesn't return genres)
  console.log('Phase 1: Searching for Spotify IDs...\n');
  const artistIdMap = new Map(); // artist name -> { id, spotifyName }

  for (let i = 0; i < toFetch.length; i++) {
    const { name, play_count } = toFetch[i];
    process.stdout.write(`[${i + 1}/${toFetch.length}] "${name}" (${play_count} plays)... `);

    try {
      const found = await searchArtistId(name, token);
      if (!found) {
        console.log('not found');
        noResultCount++;
      } else {
        console.log(`ID: ${found.id} "${found.name}"`);
        artistIdMap.set(name, found);
      }
      // Rate limit: ~3 requests/second
      await sleep(350);
    } catch (err) {
      console.log(`ERROR: ${err.message}`);
    }
  }

  // Phase 2: Batch-fetch full artist data (with genres) in chunks of 50
  console.log(`\nPhase 2: Fetching genres for ${artistIdMap.size} artists in batches of 50...\n`);
  const artistEntries = Array.from(artistIdMap.entries());

  for (let i = 0; i < artistEntries.length; i += 50) {
    const batch = artistEntries.slice(i, i + 50);
    const ids = batch.map(([, found]) => found.id);

    try {
      const fullArtists = await fetchArtistsByIds(ids, token);

      for (const fullArtist of fullArtists) {
        if (!fullArtist) continue;
        const genres = JSON.stringify(fullArtist.genres || []);
        const imageUrl = fullArtist.images?.[0]?.url || null;

        if ((fullArtist.genres || []).length === 0) noGenreCount++;

        // Use pool.query() (not a persistent client) to avoid connection timeouts
        await pool.query(`
          INSERT INTO artists (id, name, genres, image_url)
          VALUES ($1, $2, $3::jsonb, $4)
          ON CONFLICT (id) DO UPDATE
            SET name = EXCLUDED.name,
                genres = EXCLUDED.genres,
                image_url = COALESCE(EXCLUDED.image_url, artists.image_url)
        `, [fullArtist.id, fullArtist.name, genres, imageUrl]);

        console.log(`  ${fullArtist.name}: [${(fullArtist.genres || []).join(', ') || 'no genres'}]`);
        successCount++;
      }

      await sleep(200);
    } catch (err) {
      console.log(`Batch error (${i}-${i + 50}): ${err.message}`);
    }
  }

  console.log(`\n📊 Results:`);
  console.log(`  ✓ Upserted: ${successCount} artists`);
  console.log(`  ○ No genres: ${noGenreCount} artists`);
  console.log(`  ✗ Not found: ${noResultCount} artists`);

  // Show final genre coverage
  const { rows: coverage } = await pool.query(`
    SELECT
      COUNT(DISTINCT t.artist_name) as total_artists,
      COUNT(DISTINCT CASE WHEN ar.genres IS NOT NULL AND ar.genres != '[]' THEN t.artist_name END) as with_genres,
      SUM(le_counts.play_count) as total_plays,
      SUM(CASE WHEN ar.genres IS NOT NULL AND ar.genres != '[]' THEN le_counts.play_count ELSE 0 END) as plays_with_genres
    FROM (
      SELECT t.artist_name, COUNT(*) as play_count
      FROM listening_events le JOIN tracks t ON le.track_id = t.id
      WHERE t.artist_name IS NOT NULL
      GROUP BY t.artist_name
    ) le_counts
    JOIN tracks t ON t.artist_name = le_counts.artist_name
    LEFT JOIN artists ar ON ar.name = t.artist_name
  `);
  const cov = coverage[0];
  if (cov) {
    const artistPct = ((cov.with_genres / cov.total_artists) * 100).toFixed(1);
    const playPct = ((cov.plays_with_genres / cov.total_plays) * 100).toFixed(1);
    console.log(`\n🎵 Genre Coverage:`);
    console.log(`  Artists: ${cov.with_genres}/${cov.total_artists} (${artistPct}%)`);
    console.log(`  Plays:   ${cov.plays_with_genres}/${cov.total_plays} (${playPct}%)`);
  }

  await pool.end();
  console.log('\nDone!\n');
}

main().catch(err => { console.error(err); process.exit(1); });
