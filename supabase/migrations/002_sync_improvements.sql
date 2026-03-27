-- ============================================================
-- Sinapsis - Sync Improvements Migration
-- Adds missing columns, indexes, policies, and realtime support
-- ============================================================

-- ============================================================
-- MISSING COLUMNS
-- ============================================================

-- Add updated_at to study_sessions and pomodoro_sessions for sync
ALTER TABLE public.study_sessions
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.pomodoro_sessions
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- ============================================================
-- UPDATED_AT TRIGGERS for sessions tables
-- ============================================================

CREATE TRIGGER on_study_sessions_updated
  BEFORE UPDATE ON public.study_sessions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_pomodoro_sessions_updated
  BEFORE UPDATE ON public.pomodoro_sessions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- COMPOSITE INDEXES for efficient sync queries
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_courses_user_updated
  ON public.courses(user_id, updated_at);

CREATE INDEX IF NOT EXISTS idx_notes_user_updated
  ON public.notes(user_id, updated_at);

CREATE INDEX IF NOT EXISTS idx_study_sessions_user_created
  ON public.study_sessions(user_id, created_at);

CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_user_created
  ON public.pomodoro_sessions(user_id, created_at);

-- Synced_at indexes
CREATE INDEX IF NOT EXISTS idx_courses_synced_at
  ON public.courses(synced_at);

CREATE INDEX IF NOT EXISTS idx_notes_synced_at
  ON public.notes(synced_at);

-- Partial indexes for active (non-deleted) records
CREATE INDEX IF NOT EXISTS idx_courses_active
  ON public.courses(user_id) WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_notes_active
  ON public.notes(user_id, course_id) WHERE is_deleted = FALSE;

-- ============================================================
-- MISSING DELETE RLS POLICIES
-- ============================================================

CREATE POLICY "Users can delete own study sessions" ON public.study_sessions
  FOR DELETE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own pomodoro sessions" ON public.pomodoro_sessions
  FOR DELETE USING (auth.uid()::text = user_id);

-- ============================================================
-- ADD SESSIONS TO REALTIME
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.study_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.pomodoro_sessions;

-- ============================================================
-- RPC: Get changes since a given timestamp (delta sync)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_changes_since(
  p_user_id TEXT,
  p_since TIMESTAMPTZ
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'courses', (
      SELECT COALESCE(json_agg(c), '[]'::json)
      FROM public.courses c
      WHERE c.user_id = p_user_id AND c.updated_at > p_since
    ),
    'notes', (
      SELECT COALESCE(json_agg(n), '[]'::json)
      FROM public.notes n
      WHERE n.user_id = p_user_id AND n.updated_at > p_since
    ),
    'study_sessions', (
      SELECT COALESCE(json_agg(s), '[]'::json)
      FROM public.study_sessions s
      WHERE s.user_id = p_user_id AND s.created_at > p_since
    ),
    'pomodoro_sessions', (
      SELECT COALESCE(json_agg(p), '[]'::json)
      FROM public.pomodoro_sessions p
      WHERE p.user_id = p_user_id AND p.created_at > p_since
    )
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
