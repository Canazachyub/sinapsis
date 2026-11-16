-- ============================================================
-- Sinapsis - app_notes table matching real app data model
-- The old 'notes' table has flashcard schema that doesn't match
-- the app's actual Note entity (title + rich content Delta JSON)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_notes (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  tags JSONB NOT NULL DEFAULT '[]'::jsonb,
  occlusion_marks JSONB NOT NULL DEFAULT '[]'::jsonb,
  image_occlusions JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_app_notes_user_id ON public.app_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_app_notes_course_id ON public.app_notes(course_id);
CREATE INDEX IF NOT EXISTS idx_app_notes_updated_at ON public.app_notes(updated_at);
CREATE INDEX IF NOT EXISTS idx_app_notes_user_updated ON public.app_notes(user_id, updated_at);

-- RLS
ALTER TABLE public.app_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own app_notes" ON public.app_notes
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own app_notes" ON public.app_notes
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own app_notes" ON public.app_notes
  FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own app_notes" ON public.app_notes
  FOR DELETE USING (auth.uid()::text = user_id);

-- Updated_at trigger
CREATE TRIGGER on_app_notes_updated
  BEFORE UPDATE ON public.app_notes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_notes;
