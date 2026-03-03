-- Migration: 001_create_imports_table
-- Description: Create imports table for tracking Spotify history import jobs
-- Created: 2024-01-01

-- UP
CREATE TABLE IF NOT EXISTS imports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,

    -- Status tracking
    status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'uploading', 'processing', 'complete', 'failed')),
    source TEXT NOT NULL DEFAULT 'spotify_export',

    -- File info
    original_filename TEXT,
    file_size_bytes BIGINT,

    -- Progress metrics
    total_files INT DEFAULT 0,
    processed_files INT DEFAULT 0,
    total_rows_seen BIGINT DEFAULT 0,
    rows_inserted BIGINT DEFAULT 0,
    rows_deduped BIGINT DEFAULT 0,

    -- Resumability support
    current_file_index INT DEFAULT 0,
    current_file_offset BIGINT DEFAULT 0,

    -- Error handling
    error_message TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for user's imports list
CREATE INDEX IF NOT EXISTS idx_imports_user_id ON imports(user_id);

-- Index for finding in-progress imports
CREATE INDEX IF NOT EXISTS idx_imports_status ON imports(status) WHERE status IN ('created', 'uploading', 'processing');

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_imports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS imports_updated_at ON imports;
CREATE TRIGGER imports_updated_at
    BEFORE UPDATE ON imports
    FOR EACH ROW
    EXECUTE FUNCTION update_imports_updated_at();

-- DOWN
-- DROP TRIGGER IF EXISTS imports_updated_at ON imports;
-- DROP FUNCTION IF EXISTS update_imports_updated_at();
-- DROP TABLE IF EXISTS imports;
