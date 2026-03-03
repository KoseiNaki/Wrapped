-- Migration: 002_create_listening_events_table
-- Description: Create listening_events table for imported Spotify history
-- Created: 2024-01-01

-- UP
CREATE TABLE IF NOT EXISTS listening_events (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    import_id UUID REFERENCES imports(id) ON DELETE CASCADE,

    -- Core listening data
    played_at TIMESTAMPTZ NOT NULL,
    ms_played INT NOT NULL,
    track_name TEXT NOT NULL,
    artist_name TEXT NOT NULL,
    album_name TEXT,

    -- Extended data (from endsong format)
    spotify_track_uri TEXT,
    spotify_artist_uri TEXT,
    spotify_album_uri TEXT,
    reason_start TEXT,
    reason_end TEXT,
    shuffle BOOLEAN,
    skipped BOOLEAN,
    offline BOOLEAN,
    incognito_mode BOOLEAN,
    platform TEXT,
    ip_addr TEXT,
    country TEXT,

    -- Source tracking
    source TEXT NOT NULL DEFAULT 'spotify_export',

    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Primary analytics index: user's history by time (descending for "recent first")
CREATE INDEX IF NOT EXISTS idx_listening_events_user_played_at
    ON listening_events(user_id, played_at DESC);

-- Index for import tracking
CREATE INDEX IF NOT EXISTS idx_listening_events_import_id
    ON listening_events(import_id);

-- Index for artist/track lookups
CREATE INDEX IF NOT EXISTS idx_listening_events_user_artist
    ON listening_events(user_id, artist_name);

-- Unique constraint for deduplication
-- Uses (user_id, played_at, track_name, artist_name, ms_played) as the unique key
-- This prevents re-importing the same listening event
CREATE UNIQUE INDEX IF NOT EXISTS idx_listening_events_dedupe
    ON listening_events(user_id, played_at, track_name, artist_name, ms_played);

-- DOWN
-- DROP INDEX IF EXISTS idx_listening_events_dedupe;
-- DROP INDEX IF EXISTS idx_listening_events_user_artist;
-- DROP INDEX IF EXISTS idx_listening_events_import_id;
-- DROP INDEX IF EXISTS idx_listening_events_user_played_at;
-- DROP TABLE IF EXISTS listening_events;
