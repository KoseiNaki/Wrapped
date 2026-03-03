#!/usr/bin/env node
/**
 * Fetch genres for artists that are still missing them.
 * Targets artists with the most plays first.
 * Uses MusicBrainz API (free, no auth).
 */

const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

const MB_USER_AGENT = 'WrappedApp/1.0 (naki@wrappedapp.test)';
const MB_DELAY_MS = 1200;

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
    const artists = data.artists || [];
    const exact = artists.find(a => a.name.toLowerCase() === name.toLowerCase());
    return exact || artists[0] || null;
  } catch (err) {
    clearTimeout(timeout);
    if (err.name === 'AbortError') throw new Error(`Timeout for "${name}"`);
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
      console.log('  Rate limited, waiting 10s...');
      await sleep(10000);
      return getArtistTags(mbid);
    }
    if (!res.ok) throw new Error(`MusicBrainz error: ${res.status}`);
    const data = await res.json();
    const tags = (data.tags || [])
      .filter(t => t.count > 0)
      .sort((a, b) => b.count - a.count)
      .slice(0, 5)
      .map(t => t.name);
    return tags;
  } catch (err) {
    clearTimeout(timeout);
    if (err.name === 'AbortError') throw new Error(`Timeout for MBID ${mbid}`);
    throw err;
  }
}

async function main() {
  console.log('\n🎤 Fetch Missing Artist Genres from MusicBrainz\n');

  // Get artists that DON'T have genres yet, ordered by play count
  const { rows: toFetch } = await pool.query(`
    SELECT t.artist_name AS name, COUNT(*) AS play_count
    FROM listening_events le
    JOIN tracks t ON le.track_id = t.id
    WHERE t.artist_name IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM artists a
        WHERE a.name = t.artist_name
          AND a.genres IS NOT NULL AND a.genres != '[]'
      )
    GROUP BY t.artist_name
    ORDER BY play_count DESC
    LIMIT 500
  `);

  console.log(`Found ${toFetch.length} artists without genres`);
  console.log(`(~1.2s per artist × 2 requests = ~${Math.round(toFetch.length * 2.4 / 60)} minutes)\n`);

  let successCount = 0, noTagCount = 0, noResultCount = 0;

  for (let i = 0; i < toFetch.length; i++) {
    const { name, play_count } = toFetch[i];
    process.stdout.write(`[${i + 1}/${toFetch.length}] "${name}" (${play_count} plays)... `);

    try {
      const artist = await searchArtistOnMB(name);
      await sleep(MB_DELAY_MS);

      if (!artist) {
        console.log('not found');
        noResultCount++;
        continue;
      }

      const tags = await getArtistTags(artist.id);
      await sleep(MB_DELAY_MS);

      if (tags.length === 0) {
        noTagCount++;
        console.log(`no genres (MB: "${artist.name}")`);
      } else {
        console.log(`[${tags.join(', ')}]`);
      }

      // Update existing artist rows with matching name
      await pool.query(`
        UPDATE artists SET genres = $1::jsonb
        WHERE name = $2 AND (genres IS NULL OR genres = '[]')
      `, [JSON.stringify(tags), name]);

      // Also insert if no row exists at all
      const artistId = 'mb-' + artist.id.replace(/-/g, '').substring(0, 22);
      await pool.query(`
        INSERT INTO artists (id, name, genres)
        VALUES ($1, $2, $3::jsonb)
        ON CONFLICT (id) DO UPDATE SET genres = EXCLUDED.genres
      `, [artistId, name, JSON.stringify(tags)]);

      if (tags.length > 0) successCount++;
    } catch (err) {
      console.log(`ERROR: ${err.message}`);
    }
  }

  console.log(`\n📊 Results:`);
  console.log(`  ✓ Genres found: ${successCount}`);
  console.log(`  ○ No genres: ${noTagCount}`);
  console.log(`  ✗ Not found: ${noResultCount}`);

  await pool.end();
  console.log('\nDone!\n');
}

main().catch(err => { console.error(err); process.exit(1); });
