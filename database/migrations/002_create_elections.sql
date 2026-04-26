-- Migration: 002_create_elections
-- Creates elections and candidates tables

DO $$ BEGIN
    CREATE TYPE election_status AS ENUM ('draft', 'upcoming', 'active', 'completed', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS elections (
    id               UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
    title            VARCHAR(255)     NOT NULL,
    description      TEXT,
    start_time       TIMESTAMPTZ      NOT NULL,
    end_time         TIMESTAMPTZ      NOT NULL,
    status           election_status  NOT NULL DEFAULT 'draft',
    created_by       UUID             NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    is_public_results BOOLEAN         NOT NULL DEFAULT TRUE,
    results_published BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_election_times CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_elections_status     ON elections(status);
CREATE INDEX IF NOT EXISTS idx_elections_created_by ON elections(created_by);
CREATE INDEX IF NOT EXISTS idx_elections_times      ON elections(start_time, end_time);

CREATE TRIGGER trg_elections_updated_at
    BEFORE UPDATE ON elections
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_updated_at();

-- Candidates belong to elections
CREATE TABLE IF NOT EXISTS candidates (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    election_id UUID        NOT NULL REFERENCES elections(id) ON DELETE CASCADE,
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    manifesto   TEXT,
    position    VARCHAR(100),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_election_candidate UNIQUE (election_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_candidates_election_id ON candidates(election_id);
CREATE INDEX IF NOT EXISTS idx_candidates_user_id ON candidates(user_id);

COMMENT ON TABLE elections IS 'Academic council elections with time-based lifecycle management';
COMMENT ON COLUMN elections.status IS 'Managed by a scheduled job or trigger based on start/end time';

