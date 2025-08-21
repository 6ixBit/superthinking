-- Pattern Exploration Migration
-- Add support for pattern exploration insights and enhanced action items

-- First, update action_items table to support deeper_exploration source
ALTER TABLE action_items 
DROP CONSTRAINT action_items_source_check,
ADD CONSTRAINT action_items_source_check 
CHECK (source IN ('user_stated', 'ai_suggested', 'deeper_exploration'));

-- Create Pattern Exploration Insights Table
CREATE TABLE pattern_exploration_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES sessions(id),
    pattern_type TEXT NOT NULL,
    original_question TEXT,
    exploration_transcript TEXT,
    insight TEXT,
    key_realization TEXT,
    encouragement TEXT,
    audio_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add RLS policies for pattern_exploration_insights
ALTER TABLE pattern_exploration_insights ENABLE ROW LEVEL SECURITY;

-- Users can only access their own pattern exploration insights
CREATE POLICY "Users can view own pattern exploration insights" ON pattern_exploration_insights
    FOR SELECT USING (
        session_id IN (
            SELECT id FROM sessions WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own pattern exploration insights" ON pattern_exploration_insights
    FOR INSERT WITH CHECK (
        session_id IN (
            SELECT id FROM sessions WHERE user_id = auth.uid()
        )
    );

-- Add indexes for better performance
CREATE INDEX idx_pattern_exploration_session_id ON pattern_exploration_insights(session_id);
CREATE INDEX idx_pattern_exploration_created_at ON pattern_exploration_insights(created_at);

-- Add a trigger to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_pattern_exploration_insights_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_pattern_exploration_insights_updated_at
    BEFORE UPDATE ON pattern_exploration_insights
    FOR EACH ROW
    EXECUTE FUNCTION update_pattern_exploration_insights_updated_at(); 