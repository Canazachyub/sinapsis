-- ============================================================
-- Sinapsis - Initial Supabase Schema
-- Mirrors local Drift database with sync support
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLES
-- ============================================================

-- Users table (mirrors auth.users but stores app-specific data)
CREATE TABLE IF NOT EXISTS public.users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Courses table
CREATE TABLE IF NOT EXISTS public.courses (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  color TEXT NOT NULL DEFAULT '#6366F1',
  is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at TIMESTAMPTZ
);

-- Notes table
CREATE TABLE IF NOT EXISTS public.notes (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  front_content TEXT NOT NULL,
  back_content TEXT,
  tags TEXT,
  difficulty INTEGER NOT NULL DEFAULT 0,
  last_reviewed TIMESTAMPTZ,
  next_review TIMESTAMPTZ,
  review_count INTEGER NOT NULL DEFAULT 0,
  interval INTEGER NOT NULL DEFAULT 0,
  ease_factor DOUBLE PRECISION NOT NULL DEFAULT 2.5,
  consecutive_correct INTEGER NOT NULL DEFAULT 0,
  srs_state TEXT NOT NULL DEFAULT 'new',
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at TIMESTAMPTZ
);

-- Study sessions table
CREATE TABLE IF NOT EXISTS public.study_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  course_id TEXT NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  cards_reviewed INTEGER NOT NULL,
  cards_correct INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  session_type TEXT NOT NULL DEFAULT 'review',
  note_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at TIMESTAMPTZ
);

-- Pomodoro sessions table
CREATE TABLE IF NOT EXISTS public.pomodoro_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  course_id TEXT REFERENCES public.courses(id) ON DELETE SET NULL,
  note_id TEXT,
  work_duration INTEGER NOT NULL DEFAULT 1500,
  break_duration INTEGER NOT NULL DEFAULT 300,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  was_interrupted BOOLEAN NOT NULL DEFAULT FALSE,
  started_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at TIMESTAMPTZ
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_courses_user_id ON public.courses(user_id);
CREATE INDEX IF NOT EXISTS idx_courses_updated_at ON public.courses(updated_at);

CREATE INDEX IF NOT EXISTS idx_notes_course_id ON public.notes(course_id);
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON public.notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON public.notes(updated_at);
CREATE INDEX IF NOT EXISTS idx_notes_next_review ON public.notes(next_review);

CREATE INDEX IF NOT EXISTS idx_study_sessions_user_id ON public.study_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_study_sessions_course_id ON public.study_sessions(course_id);

CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_user_id ON public.pomodoro_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_course_id ON public.pomodoro_sessions(course_id);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pomodoro_sessions ENABLE ROW LEVEL SECURITY;

-- Users: users can only access their own row
CREATE POLICY "Users can view own data" ON public.users
  FOR SELECT USING (auth.uid()::text = id);

CREATE POLICY "Users can insert own data" ON public.users
  FOR INSERT WITH CHECK (auth.uid()::text = id);

CREATE POLICY "Users can update own data" ON public.users
  FOR UPDATE USING (auth.uid()::text = id);

-- Courses: users can only access their own courses
CREATE POLICY "Users can view own courses" ON public.courses
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own courses" ON public.courses
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own courses" ON public.courses
  FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own courses" ON public.courses
  FOR DELETE USING (auth.uid()::text = user_id);

-- Notes: users can only access their own notes
CREATE POLICY "Users can view own notes" ON public.notes
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own notes" ON public.notes
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own notes" ON public.notes
  FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own notes" ON public.notes
  FOR DELETE USING (auth.uid()::text = user_id);

-- Study sessions: users can only access their own sessions
CREATE POLICY "Users can view own study sessions" ON public.study_sessions
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own study sessions" ON public.study_sessions
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own study sessions" ON public.study_sessions
  FOR UPDATE USING (auth.uid()::text = user_id);

-- Pomodoro sessions: users can only access their own sessions
CREATE POLICY "Users can view own pomodoro sessions" ON public.pomodoro_sessions
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own pomodoro sessions" ON public.pomodoro_sessions
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own pomodoro sessions" ON public.pomodoro_sessions
  FOR UPDATE USING (auth.uid()::text = user_id);

-- ============================================================
-- REALTIME
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.courses;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notes;

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_courses_updated
  BEFORE UPDATE ON public.courses
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_notes_updated
  BEFORE UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_users_updated
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
