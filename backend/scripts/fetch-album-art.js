#!/usr/bin/env node
/**
 * Fetch Album Art from Spotify API
 */

const { Pool } = require('pg');
const https = require('https');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

const SPOTIFY_CLIENT_ID = process.env.SPOTIFY_CLIENT_ID;
const SPOTIFY_CLIENT_SECRET = process.env.SPOTIFY_CLIENT_SECRET;

if (!SPOTIFY_CLIENT_ID || !SPOTIFY_CLIENT_SECRET) {
  console.log('❌ SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET required');
  process.exit(1);
}

async function getAccessToken() {
  return new Promise((resolve, reject) => {
    const auth = Buffer.from(`${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`).toString('base64');

    const req = https.request({
      hostname: 'accounts.spotify.com',
      path: '/api/token',
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const json = JSON.parse(data);
        if (json.access_token) resolve(json.access_token);
        else reject(new Error(json.error_description || 'Token error'));
      });
    });

    req.on('error', reject);
    req.write('grant_type=client_credentials');
    req.end();
  });
}

async function fetchTrack(accessToken, trackId) {
  return new Promise((resolve) => {
    const req = https.request({
      hostname: 'api.spotify.com',
      path: `/v1/tracks/${trackId}`,
      method: 'GET',
      headers: { 'Authorization': `Bearer ${accessToken}` }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const track = JSON.parse(data);
          if (res.statusCode === 200 && track.album) {
            resolve(track);
          } else {
            resolve(null);
          }
        } catch {
          resolve(null);
        }
      });
    });

    req.on('error', () => resolve(null));
    req.end();
  });
}

async function main() {
  console.log('\n🎨 Fetching Album Art from Spotify\n');

  const accessToken = await getAccessToken();
  console.log('✅ Got access token\n');

  // Get tracks that need album art - prioritize by play count
  const tracksResult = await pool.query(`
    SELECT t.id, COUNT(le.id) as play_count
    FROM tracks t
    JOIN listening_events le ON t.id = le.track_id
    WHERE t.album_id IS NULL
    GROUP BY t.id
    ORDER BY play_count DESC
    LIMIT 500
  `);

  const trackIds = tracksResult.rows.map(r => r.id);
  console.log(`Found ${trackIds.length} top tracks without album art\n`);

  let updated = 0;
  let failed = 0;

  for (let i = 0; i < trackIds.length; i++) {
    const trackId = trackIds[i];

    try {
      const track = await fetchTrack(accessToken, trackId);

      if (track && track.album) {
        const album = track.album;
        const imageUrl = album.images?.[0]?.url || null;

        // Update track with album_id
        await pool.query('UPDATE tracks SET album_id = $1 WHERE id = $2', [album.id, trackId]);

        // Upsert album
        await pool.query(`
          INSERT INTO albums (id, name, image_url, external_url)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT (id) DO UPDATE SET
            image_url = COALESCE(EXCLUDED.image_url, albums.image_url)
        `, [album.id, album.name, imageUrl, album.external_urls?.spotify]);

        updated++;
      } else {
        failed++;
      }

      process.stdout.write(`Progress: ${i + 1}/${trackIds.length} (${updated} updated, ${failed} failed)\r`);

      // Rate limit
      await new Promise(r => setTimeout(r, 50));

    } catch (err) {
      failed++;
    }
  }

  console.log(`\n\n✅ Updated ${updated} tracks with album art\n`);
  await pool.end();
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
