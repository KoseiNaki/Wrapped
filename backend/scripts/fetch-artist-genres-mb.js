#!/usr/bin/env node
/**
 * Fetch artist genres from MusicBrainz API (free, no auth required).
 * Gets top artists by play count and fetches their genre tags from MusicBrainz.
 *
 * Usage: DATABASE_URL=... node fetch-artist-genres-mb.js
 * Rate limit: MusicBrainz allows ~1 req/second. We use 1.2s delay to be safe.
 */

const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

const MB_USER_AGENT = 'WrappedApp/1.0 (naki@wrappedapp.test)';
const MB_DELAY_MS = 1200; // 1.2 seconds between requests

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function searchArtistOnMB(name) {
  const url = `https://musicbrainz.org/ws/2/artist/?query=${encodeURIComponent(name)}&limit=3&fmt=json`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': MB_USER_AGENT },
      signal: controller.signal
    });
    clearTimeout(timeout);
    if (res.status === 503 || res.status === 429) {
      console.log('  Rate limited, waiting 10s...');
      await sleep(10000);
      return searchArtistOnMB(name);
    }
    if (!res.ok) throw new Error(`MusicBrainz error: ${res.status}`);
    const data = await res.json();
    // Find best match by name similarity
    const artists = data.artists || [];
    const exact = artists.find(a => a.name.toLowerCase() === name.toLowerCase());
    return exact || artists[0] || null;
  } catch (err) {
    clearTimeout(timeout);
    if (err.name === 'AbortError') throw new Error(`Timeout searching MusicBrainz for "${name}"`);
    throw err;
  }
}

async function getArtistTags(mbid) {
  const url = `https://musicbrainz.org/ws/2/artist/${mbid}?inc=tags&fmt=json`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': MB_USER_AGENT },
      signal: controller.signal
    });
    clearTimeout(timeout);
    if (res.status === 503 || res.status === 429) {
      await sleep(10000);
      return getArtistTags(mbid);
    }
    if (!res.ok) throw new Error(`MusicBrainz tag error: ${res.status}`);
    const data = await res.json();
    // Filter to music genre tags (exclude language, country tags)
    const skipTags = new Set(['english', 'american', 'british', 'australian', 'canadian', 'japanese', 'korean', 'german', 'french', 'spanish', 'italian', 'swedish', 'norwegian', 'dutch', 'danish']);
    const tags = (data.tags || [])
      .filter(t => t.count > 0 && !skipTags.has(t.name.toLowerCase()))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5)
      .map(t => t.name);
    return tags;
  } catch (err) {
    clearTimeout(timeout);
    if (err.name === 'AbortError') throw new Error(`Timeout fetching tags for ${mbid}`);
    throw err;
  }
}

async function main() {
  console.log('\n🎤 Fetch Artist Genres from MusicBrainz\n');

  // Get top artists by play count
  const { rows: topArtists } = await pool.query(`
    SELECT t.artist_name AS name, COUNT(*) AS play_count
    FROM listening_events le
    JOIN tracks t ON le.track_id = t.id
    WHERE t.artist_name IS NOT NULL
    GROUP BY t.artist_name
    ORDER BY play_count DESC
    LIMIT 500
  `);

  console.log(`Found ${topArtists.length} top artists\n`);

  // Check which already have genres
  const { rows: existing } = await pool.query(
    `SELECT name FROM artists WHERE genres IS NOT NULL AND genres != '[]'`
  );
  const existingSet = new Set(existing.map(r => r.name.toLowerCase()));
  console.log(`${existing.length} artists already have genres\n`);

  const toFetch = topArtists.filter(a => !existingSet.has(a.name.toLowerCase()));
  console.log(`Fetching genres for ${toFetch.length} artists from MusicBrainz...\n`);
  console.log('(~1.2s per artist, this will take ~' + Math.round(toFetch.length * 1.2 * 2 / 60) + ' minutes)\n');

  let successCount = 0, noTagCount = 0, noResultCount = 0;

  for (let i = 0; i < toFetch.length; i++) {
    const { name, play_count } = toFetch[i];
    process.stdout.write(`[${i + 1}/${toFetch.length}] "${name}" (${play_count} plays)... `);

    try {
      // Step 1: Search for MBID
      const artist = await searchArtistOnMB(name);
      await sleep(MB_DELAY_MS);

      if (!artist) {
        console.log('not found on MusicBrainz');
        noResultCount++;
        continue;
      }

      // Step 2: Fetch tags with MBID
      const tags = await getArtistTags(artist.id);
      await sleep(MB_DELAY_MS);

      if (tags.length === 0) {
        noTagCount++;
        console.log(`no genres (MB: "${artist.name}")`);
      } else {
        console.log(`[${tags.join(', ')}]`);
      }

      // Upsert artist with a fake Spotify-like ID using MB ID
      const artistId = 'mb-' + artist.id.replace(/-/g, '').substring(0, 22);
      await pool.query(`
        INSERT INTO artists (id, name, genres)
        VALUES ($1, $2, $3::jsonb)
        ON CONFLICT (id) DO UPDATE
          SET name = EXCLUDED.name, genres = EXCLUDED.genres
      `, [artistId, name, JSON.stringify(tags)]);

      // Also try to update any existing artist with matching name
      await pool.query(`
        UPDATE artists SET genres = $1::jsonb
        WHERE name = $2 AND (genres IS NULL OR genres = '[]')
      `, [JSON.stringify(tags), name]);

      successCount++;
    } catch (err) {
      console.log(`ERROR: ${err.message}`);
    }
  }

  console.log(`\n📊 Results:`);
  console.log(`  ✓ Genres found: ${successCount}`);
  console.log(`  ○ No genres: ${noTagCount}`);
  console.log(`  ✗ Not found: ${noResultCount}`);

  // Show coverage
  const { rows: cov } = await pool.query(`
    SELECT
      COUNT(DISTINCT t.artist_name) as total_artists,
      COUNT(DISTINCT CASE WHEN ar.genres IS NOT NULL AND ar.genres != '[]' THEN t.artist_name END) as with_genres
    FROM tracks t
    LEFT JOIN artists ar ON ar.name = t.artist_name
    WHERE t.artist_name IS NOT NULL
  `);
  if (cov[0]) {
    const pct = ((cov[0].with_genres / cov[0].total_artists) * 100).toFixed(1);
    console.log(`\n🎵 Genre Coverage: ${cov[0].with_genres}/${cov[0].total_artists} artists (${pct}%)`);
  }

  await pool.end();
  console.log('\nDone!\n');
}

main().catch(err => { console.error(err); process.exit(1); });
