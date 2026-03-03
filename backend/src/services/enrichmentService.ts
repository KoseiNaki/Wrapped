/**
 * Enrichment Service (STUB)
 *
 * Future implementation to enrich imported listening events with
 * additional Spotify metadata like:
 * - Spotify track IDs (via search API)
 * - Audio features (danceability, energy, valence, etc.)
 * - Genre information
 * - Album artwork URLs
 *
 * This runs as a background job AFTER import completes.
 * It does NOT block the import process.
 */

import { query } from '../config/database';

export interface EnrichmentJob {
  id: string;
  import_id: string;
  user_id: string;
  status: 'pending' | 'processing' | 'complete' | 'failed';
  total_events: number;
  enriched_events: number;
  failed_events: number;
  created_at: Date;
  finished_at: Date | null;
}

/**
 * Create an enrichment job for a completed import
 *
 * TODO: Implement when Spotify API integration is ready
 */
export async function createEnrichmentJob(
  importId: string,
  userId: string
): Promise<EnrichmentJob | null> {
  console.log(`[STUB] Creating enrichment job for import ${importId}`);

  // Stub implementation - return null until implemented
  return null;
}

/**
 * Process enrichment job - lookup Spotify metadata for events
 *
 * TODO: Implement with Spotify Web API
 *
 * Implementation notes:
 * 1. Query events without spotify_track_uri
 * 2. For each batch (100 events):
 *    - Search Spotify API: /v1/search?q=track:{name}+artist:{artist}&type=track
 *    - Match first result with high confidence
 *    - Update listening_events.spotify_track_uri
 * 3. Optionally fetch audio features for matched tracks
 *    - /v1/audio-features?ids={comma-separated-ids}
 *
 * Rate limiting considerations:
 * - Spotify allows 30 requests/second for search
 * - Batch lookups where possible
 * - Add exponential backoff on 429 errors
 */
export async function processEnrichmentJob(jobId: string): Promise<void> {
  console.log(`[STUB] Processing enrichment job ${jobId}`);

  // Stub implementation - do nothing until implemented
}

/**
 * Get events that need enrichment (no spotify_track_uri)
 */
export async function getUnenrichedEvents(
  importId: string,
  limit: number = 100
): Promise<Array<{ id: number; track_name: string; artist_name: string }>> {
  const { rows } = await query<{ id: number; track_name: string; artist_name: string }>(
    `SELECT id, track_name, artist_name
     FROM listening_events
     WHERE import_id = $1
       AND spotify_track_uri IS NULL
     LIMIT $2`,
    [importId, limit]
  );

  return rows;
}

/**
 * Update event with Spotify metadata
 */
export async function updateEventWithSpotifyData(
  eventId: number,
  spotifyTrackUri: string,
  albumName?: string
): Promise<void> {
  await query(
    `UPDATE listening_events
     SET spotify_track_uri = $1,
         album_name = COALESCE($2, album_name)
     WHERE id = $3`,
    [spotifyTrackUri, albumName || null, eventId]
  );
}
