#!/usr/bin/env node
/**
 * Standalone Stats Server
 *
 * Serves stats endpoints using the imported Spotify data
 */

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3000;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

app.use(cors());
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// Health check
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', error: error.message });
  }
});

// Helper to decode JWT and get user ID
function getUserId(req) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) return null;

  try {
    const token = authHeader.split(' ')[1];
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    return payload.sub || payload.user_id;
  } catch {
    return null;
  }
}

// GET /me - User profile
app.get('/me', async (req, res) => {
  const userId = getUserId(req);
  if (!userId) {
    return res.status(401).json({ error: 'unauthorized', message: 'Invalid or missing authorization token' });
  }

  try {
    const result = await pool.query(`
      SELECT id, spotify_id, spotify_display_name, custom_display_name,
             sync_enabled, sync_interval_minutes, last_sync_at, created_at
      FROM users WHERE id = $1
    `, [userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'NotFound', message: 'User not found' });
    }

    const user = result.rows[0];
    res.json({
      id: user.id,
      spotify_id: user.spotify_id,
      display_name: user.custom_display_name || user.spotify_display_name,
      sync_enabled: user.sync_enabled,
      sync_interval_minutes: user.sync_interval_minutes,
      last_sync_at: user.last_sync_at?.toISOString() || null,
      created_at: user.created_at.toISOString()
    });
  } catch (error) {
    console.error('Profile error:', error);
    res.status(500).json({ error: 'InternalError', message: error.message });
  }
});

// GET /me/stats - Listening statistics
app.get('/me/stats', async (req, res) => {
  const userId = getUserId(req);
  if (!userId) {
    return res.status(401).json({ error: 'unauthorized', message: 'Invalid or missing authorization token' });
  }

  const period = req.query.period || 'all';
  const offset = parseInt(req.query.offset) || 0;

  // Calculate date filter based on period and offset
  let dateFilter = '';

  // Helper to get date range for period + offset
  function getDateRange(period, offset) {
    const now = new Date();
    let start, end;

    switch (period) {
      case '1d':
      case 'day':
        start = new Date(now);
        start.setDate(start.getDate() + offset);
        start.setHours(0, 0, 0, 0);
        end = new Date(start);
        end.setDate(end.getDate() + 1);
        break;
      case '7d':
      case 'week':
        // Get start of current week (Sunday)
        start = new Date(now);
        start.setDate(start.getDate() - start.getDay() + (offset * 7));
        start.setHours(0, 0, 0, 0);
        end = new Date(start);
        end.setDate(end.getDate() + 7);
        break;
      case '30d':
      case 'month':
        start = new Date(now.getFullYear(), now.getMonth() + offset, 1);
        end = new Date(now.getFullYear(), now.getMonth() + offset + 1, 1);
        break;
      case '365d':
      case 'year':
        start = new Date(now.getFullYear() + offset, 0, 1);
        end = new Date(now.getFullYear() + offset + 1, 0, 1);
        break;
      default:
        return null;
    }
    return { start, end };
  }

  const range = getDateRange(period, offset);
  if (range) {
    const startISO = range.start.toISOString();
    const endISO = range.end.toISOString();
    dateFilter = `AND played_at >= '${startISO}' AND played_at < '${endISO}'`;
  }

  try {
    // Aggregate stats - use ms_played if available, otherwise track duration
    const aggResult = await pool.query(`
      SELECT
        COUNT(*) as total_tracks,
        COALESCE(SUM(
          CASE
            WHEN le.ms_played > 0 THEN le.ms_played
            ELSE COALESCE(t.duration_ms, 180000)
          END
        )::numeric / 1000 / 60, 0) as total_minutes,
        COUNT(DISTINCT le.track_id) as unique_tracks
      FROM listening_events le
      LEFT JOIN tracks t ON le.track_id = t.id
      WHERE le.user_id = $1
        ${dateFilter}
    `, [userId]);

    const agg = aggResult.rows[0];

    // Top tracks - use ms_played if available, otherwise track duration (limit 50)
    // Also fetch primary artist's genres via name match against the artists table
    // Use DISTINCT ON to avoid duplicate artist rows inflating play counts
    const tracksResult = await pool.query(`
      SELECT
        t.id,
        t.name,
        t.artist_name,
        a.image_url as album_image_url,
        ag.genres,
        COUNT(*) as play_count,
        COALESCE(SUM(
          CASE
            WHEN le.ms_played > 0 THEN le.ms_played
            ELSE COALESCE(t.duration_ms, 180000)
          END
        )::numeric / 1000 / 60, 0) as total_minutes
      FROM listening_events le
      JOIN tracks t ON le.track_id = t.id
      LEFT JOIN albums a ON t.album_id = a.id
      LEFT JOIN (
        SELECT DISTINCT ON (name) name, genres
        FROM artists
        WHERE genres IS NOT NULL AND genres != '[]'
        ORDER BY name, id
      ) ag ON ag.name = t.artist_name
      WHERE le.user_id = $1
        ${dateFilter}
      GROUP BY t.id, t.name, t.artist_name, a.image_url, ag.genres
      ORDER BY play_count DESC
      LIMIT 50
    `, [userId]);

    // Top artists - aggregate by artist_name, join genres from artists table
    // Use DISTINCT ON to avoid duplicate artist rows inflating play counts
    const artistsResult = await pool.query(`
      SELECT
        t.artist_name as name,
        ag.genres,
        COUNT(*) as play_count,
        COUNT(DISTINCT t.id) as track_count,
        COALESCE(SUM(
          CASE
            WHEN le.ms_played > 0 THEN le.ms_played
            ELSE COALESCE(t.duration_ms, 180000)
          END
        )::numeric / 1000 / 60, 0) as total_minutes
      FROM listening_events le
      JOIN tracks t ON le.track_id = t.id
      LEFT JOIN (
        SELECT DISTINCT ON (name) name, genres
        FROM artists
        WHERE genres IS NOT NULL AND genres != '[]'
        ORDER BY name, id
      ) ag ON ag.name = t.artist_name
      WHERE le.user_id = $1
        AND t.artist_name IS NOT NULL
        ${dateFilter}
      GROUP BY t.artist_name, ag.genres
      ORDER BY play_count DESC
      LIMIT 50
    `, [userId]);

    // Count unique artists
    const uniqueArtistsResult = await pool.query(`
      SELECT COUNT(DISTINCT t.artist_name) as count
      FROM listening_events le
      JOIN tracks t ON le.track_id = t.id
      WHERE le.user_id = $1
        AND t.artist_name IS NOT NULL
        ${dateFilter}
    `, [userId]);

    // Daily stats (for charts) - use ms_played if available, otherwise track duration
    const dailyResult = await pool.query(`
      SELECT
        TO_CHAR(DATE(le.played_at), 'YYYY-MM-DD') as date,
        COUNT(*) as track_count,
        COALESCE(SUM(
          CASE
            WHEN le.ms_played > 0 THEN le.ms_played
            ELSE COALESCE(t.duration_ms, 180000)
          END
        )::numeric / 1000 / 60, 0) as minutes
      FROM listening_events le
      LEFT JOIN tracks t ON le.track_id = t.id
      WHERE le.user_id = $1
      GROUP BY DATE(le.played_at)
      ORDER BY DATE(le.played_at) DESC
      LIMIT 365
    `, [userId]);

    // Top genres - real data from artists table (matched by artist name)
    // Use DISTINCT ON subquery to avoid duplicate artist rows inflating counts
    const genresResult = await pool.query(`
      SELECT
        genre,
        COUNT(*) as play_count,
        COALESCE(SUM(
          CASE
            WHEN le.ms_played > 0 THEN le.ms_played
            ELSE COALESCE(t.duration_ms, 180000)
          END
        )::numeric / 1000 / 60, 0) as total_minutes
      FROM listening_events le
      JOIN tracks t ON le.track_id = t.id
      JOIN (
        SELECT DISTINCT ON (name) name, genres
        FROM artists
        WHERE genres IS NOT NULL AND genres != '[]'
        ORDER BY name, id
      ) ag ON ag.name = t.artist_name,
      jsonb_array_elements_text(ag.genres::jsonb) AS genre
      WHERE le.user_id = $1
        ${dateFilter}
      GROUP BY genre
      ORDER BY play_count DESC
      LIMIT 15
    `, [userId]);

    // Daily genre breakdown
    const dailyGenreResult = await pool.query(`
      SELECT
        TO_CHAR(DATE(le.played_at), 'YYYY-MM-DD') as date,
        genre,
        COALESCE(SUM(
          CASE
            WHEN le.ms_played > 0 THEN le.ms_played
            ELSE COALESCE(t.duration_ms, 180000)
          END
        )::numeric / 1000 / 60, 0) as minutes
      FROM listening_events le
      JOIN tracks t ON le.track_id = t.id
      JOIN (
        SELECT DISTINCT ON (name) name, genres
        FROM artists
        WHERE genres IS NOT NULL AND genres != '[]'
        ORDER BY name, id
      ) ag ON ag.name = t.artist_name,
      jsonb_array_elements_text(ag.genres::jsonb) AS genre
      WHERE le.user_id = $1
        ${dateFilter}
      GROUP BY DATE(le.played_at), genre
      ORDER BY DATE(le.played_at) DESC, minutes DESC
      LIMIT 1000
    `, [userId]);

    // Group daily genre stats by date
    const dailyGenreMap = {};
    for (const row of dailyGenreResult.rows) {
      if (!dailyGenreMap[row.date]) dailyGenreMap[row.date] = [];
      dailyGenreMap[row.date].push({ genre: row.genre, minutes: parseFloat(row.minutes) });
    }
    const dailyGenreStats = Object.entries(dailyGenreMap).map(([date, genres]) => ({
      date,
      genres: genres.slice(0, 8)
    }));

    res.json({
      period,
      totalTracks: parseInt(agg.total_tracks) || 0,
      totalMinutes: parseFloat(agg.total_minutes) || 0,
      uniqueTracks: parseInt(agg.unique_tracks) || 0,
      uniqueArtists: parseInt(uniqueArtistsResult.rows[0]?.count) || 0,
      topArtists: artistsResult.rows.map((a, idx) => {
        let genres = [];
        try { if (a.genres) genres = JSON.parse(a.genres); } catch (e) {}
        return {
          id: `artist-${idx}`,
          name: a.name,
          imageUrl: null,
          playCount: parseInt(a.play_count),
          totalMinutes: parseFloat(a.total_minutes),
          genres
        };
      }),
      topTracks: tracksResult.rows.map(t => {
        let genres = [];
        try { if (t.genres) genres = JSON.parse(t.genres); } catch (e) {}
        return {
          id: t.id,
          name: t.name,
          artistNames: t.artist_name ? [t.artist_name] : ['Unknown Artist'],
          albumImageUrl: t.album_image_url || null,
          playCount: parseInt(t.play_count),
          totalMinutes: parseFloat(t.total_minutes),
          popularity: null,
          genres
        };
      }),
      topGenres: genresResult.rows.map(g => ({
        genre: g.genre,
        playCount: parseInt(g.play_count),
        totalMinutes: parseFloat(g.total_minutes)
      })),
      dailyStats: dailyResult.rows.map(d => ({
        date: d.date,
        trackCount: parseInt(d.track_count),
        minutes: parseFloat(d.minutes)
      })),
      dailyGenreStats,
      averagePopularity: null
    });
  } catch (error) {
    console.error('Stats error:', error);
    res.status(500).json({ error: 'InternalError', message: error.message });
  }
});

// GET /me/history - Listening history
app.get('/me/history', async (req, res) => {
  const userId = getUserId(req);
  if (!userId) {
    return res.status(401).json({ error: 'unauthorized', message: 'Invalid or missing authorization token' });
  }

  const limit = Math.min(parseInt(req.query.limit) || 50, 100);
  const offset = parseInt(req.query.offset) || 0;

  try {
    const historyResult = await pool.query(`
      SELECT
        le.id,
        le.track_id,
        t.name as track_name,
        t.artist_name,
        t.duration_ms,
        a.name as album_name,
        a.image_url as album_image_url,
        le.played_at,
        le.ms_played,
        le.context_type,
        le.context_uri
      FROM listening_events le
      JOIN tracks t ON le.track_id = t.id
      LEFT JOIN albums a ON t.album_id = a.id
      WHERE le.user_id = $1
      ORDER BY le.played_at DESC
      LIMIT $2 OFFSET $3
    `, [userId, limit, offset]);

    const countResult = await pool.query(
      'SELECT COUNT(*) as count FROM listening_events WHERE user_id = $1',
      [userId]
    );

    res.json({
      items: historyResult.rows.map(h => ({
        id: h.id,
        track: {
          id: h.track_id,
          name: h.track_name,
          duration_ms: h.duration_ms || h.ms_played || 0,
          explicit: false,
          album: {
            id: 'unknown',
            name: h.album_name || 'Unknown Album',
            image_url: h.album_image_url || null
          },
          artists: [{ id: 'unknown', name: h.artist_name || 'Unknown Artist' }],
          audio_features: null
        },
        played_at: h.played_at.toISOString(),
        context_type: h.context_type,
        context_uri: h.context_uri
      })),
      total: parseInt(countResult.rows[0].count),
      limit,
      offset
    });
  } catch (error) {
    console.error('History error:', error);
    res.status(500).json({ error: 'InternalError', message: error.message });
  }
});

// POST /sync/now - Sync endpoint (stub)
app.post('/sync/now', async (req, res) => {
  const userId = getUserId(req);
  if (!userId) {
    return res.status(401).json({ error: 'unauthorized', message: 'Invalid or missing authorization token' });
  }

  res.json({
    success: true,
    skipped: false,
    reason: 'Using imported Spotify history',
    eventsInserted: 0,
    duplicatesSkipped: 0
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'NotFound', message: 'Endpoint not found' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Stats server running on http://localhost:${PORT}`);
  console.log('Endpoints: GET /me, GET /me/stats, GET /me/history, POST /sync/now');
});
