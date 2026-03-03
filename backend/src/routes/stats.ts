/**
 * Stats Routes
 *
 * Provides listening statistics endpoints
 */

import { Router, Request, Response } from 'express';
import { query } from '../config/database';

const router = Router();

interface StatsParams {
  userId: string;
  period: string;
}

/**
 * GET /me/stats
 * Get listening statistics for the authenticated user
 */
router.get('/me/stats', async (req: Request, res: Response) => {
  try {
    // Get user ID from JWT (simplified - in production use proper middleware)
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'unauthorized', message: 'Invalid or missing authorization token' });
    }

    const token = authHeader.split(' ')[1];

    // Decode JWT to get user ID (simplified - should verify signature in production)
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    const userId = payload.sub || payload.user_id;

    if (!userId) {
      return res.status(401).json({ error: 'unauthorized', message: 'Invalid token' });
    }

    const period = (req.query.period as string) || '7d';

    // Calculate date range based on period
    let dateFilter = '';
    if (period === '7d') {
      dateFilter = "AND played_at >= NOW() - INTERVAL '7 days'";
    } else if (period === '30d') {
      dateFilter = "AND played_at >= NOW() - INTERVAL '30 days'";
    }
    // 'all' = no date filter

    // Get aggregate stats
    const aggregateResult = await query<{
      total_tracks: string;
      total_minutes: string;
      unique_tracks: string;
      unique_artists: string;
    }>(`
      SELECT
        COUNT(*) as total_tracks,
        COALESCE(SUM(le.ms_played)::numeric / 1000 / 60, 0) as total_minutes,
        COUNT(DISTINCT le.track_id) as unique_tracks,
        0 as unique_artists
      FROM listening_events le
      WHERE le.user_id = $1
        AND le.ms_played > 30000
        ${dateFilter}
    `, [userId]);

    const agg = aggregateResult.rows[0];

    // Get top tracks
    const topTracksResult = await query<{
      id: string;
      name: string;
      play_count: string;
      total_minutes: string;
    }>(`
      SELECT
        t.id,
        t.name,
        COUNT(*) as play_count,
        COALESCE(SUM(le.ms_played)::numeric / 1000 / 60, 0) as total_minutes
      FROM listening_events le
      JOIN tracks t ON le.track_id = t.id
      WHERE le.user_id = $1
        AND le.ms_played > 30000
        ${dateFilter}
      GROUP BY t.id, t.name
      ORDER BY play_count DESC
      LIMIT 20
    `, [userId]);

    // Get daily stats
    const dailyResult = await query<{
      date: string;
      track_count: string;
      minutes: string;
    }>(`
      SELECT
        DATE(played_at) as date,
        COUNT(*) as track_count,
        COALESCE(SUM(ms_played)::numeric / 1000 / 60, 0) as minutes
      FROM listening_events
      WHERE user_id = $1
        AND ms_played > 0
        ${dateFilter}
      GROUP BY DATE(played_at)
      ORDER BY date DESC
      LIMIT 365
    `, [userId]);

    // Format response
    const stats = {
      period,
      totalTracks: parseInt(agg.total_tracks) || 0,
      totalMinutes: parseFloat(agg.total_minutes) || 0,
      uniqueTracks: parseInt(agg.unique_tracks) || 0,
      uniqueArtists: parseInt(agg.unique_artists) || 0,
      topArtists: [], // Would need artist table join
      topTracks: topTracksResult.rows.map(t => ({
        id: t.id,
        name: t.name,
        artistNames: ['Unknown Artist'], // Would need artist table
        albumImageUrl: null,
        playCount: parseInt(t.play_count),
        totalMinutes: parseFloat(t.total_minutes),
        popularity: null
      })),
      topGenres: [],
      dailyStats: dailyResult.rows.map(d => ({
        date: d.date,
        trackCount: parseInt(d.track_count),
        minutes: parseFloat(d.minutes)
      })),
      dailyGenreStats: [],
      averagePopularity: null
    };

    res.json(stats);
  } catch (error) {
    console.error('Stats error:', error);
    res.status(500).json({ error: 'InternalError', message: 'Failed to fetch stats' });
  }
});

/**
 * GET /me/history
 * Get listening history for the authenticated user
 */
router.get('/me/history', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'unauthorized', message: 'Invalid or missing authorization token' });
    }

    const token = authHeader.split(' ')[1];
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    const userId = payload.sub || payload.user_id;

    if (!userId) {
      return res.status(401).json({ error: 'unauthorized', message: 'Invalid token' });
    }

    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const offset = parseInt(req.query.offset as string) || 0;

    // Get history items
    const historyResult = await query<{
      id: string;
      track_id: string;
      track_name: string;
      played_at: Date;
      ms_played: number;
      context_type: string | null;
      context_uri: string | null;
    }>(`
      SELECT
        le.id,
        le.track_id,
        t.name as track_name,
        le.played_at,
        le.ms_played,
        le.context_type,
        le.context_uri
      FROM listening_events le
      JOIN tracks t ON le.track_id = t.id
      WHERE le.user_id = $1
      ORDER BY le.played_at DESC
      LIMIT $2 OFFSET $3
    `, [userId, limit, offset]);

    // Get total count
    const countResult = await query<{ count: string }>(
      'SELECT COUNT(*) as count FROM listening_events WHERE user_id = $1',
      [userId]
    );

    const items = historyResult.rows.map(h => ({
      id: h.id,
      track: {
        id: h.track_id,
        name: h.track_name,
        durationMs: h.ms_played || 0,
        explicit: false,
        album: {
          id: 'unknown',
          name: 'Unknown Album',
          imageURL: null
        },
        artists: [{ id: 'unknown', name: 'Unknown Artist' }],
        audioFeatures: null
      },
      playedAt: h.played_at.toISOString(),
      contextType: h.context_type,
      contextUri: h.context_uri
    }));

    res.json({
      items,
      total: parseInt(countResult.rows[0].count),
      limit,
      offset
    });
  } catch (error) {
    console.error('History error:', error);
    res.status(500).json({ error: 'InternalError', message: 'Failed to fetch history' });
  }
});

/**
 * GET /me
 * Get user profile
 */
router.get('/me', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'unauthorized', message: 'Invalid or missing authorization token' });
    }

    const token = authHeader.split(' ')[1];
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    const userId = payload.sub || payload.user_id;

    if (!userId) {
      return res.status(401).json({ error: 'unauthorized', message: 'Invalid token' });
    }

    const result = await query<{
      id: string;
      spotify_id: string;
      spotify_display_name: string | null;
      custom_display_name: string | null;
      sync_enabled: boolean;
      sync_interval_minutes: number;
      last_sync_at: Date | null;
      created_at: Date;
    }>(`
      SELECT id, spotify_id, spotify_display_name, custom_display_name,
             sync_enabled, sync_interval_minutes, last_sync_at, created_at
      FROM users
      WHERE id = $1
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
    res.status(500).json({ error: 'InternalError', message: 'Failed to fetch profile' });
  }
});

export default router;
