-- Add session title column to sessions table
-- This will store AI-generated titles that briefly describe what the session is about

-- Add the title column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sessions' 
        AND column_name = 'title'
    ) THEN
        ALTER TABLE sessions ADD COLUMN title TEXT;
    END IF;
END $$;

-- Add an index for better performance when searching by title
CREATE INDEX IF NOT EXISTS idx_sessions_title ON sessions(title) WHERE title IS NOT NULL;

-- Optional: Update existing sessions to have a default title
-- Uncomment the line below if you want to set a default title for existing sessions
-- UPDATE sessions SET title = 'Thinking Session' WHERE title IS NULL; 