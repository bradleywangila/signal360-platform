-- SIGNAL360 Sprint 08: Evidence references and immutable review history
-- Run once in the SIGNAL360-Production Supabase SQL Editor.
-- Existing submissions and building records are preserved.

ALTER TABLE public.verification_submissions
  ADD COLUMN IF NOT EXISTS evidence_type text,
  ADD COLUMN IF NOT EXISTS evidence_reference text,
  ADD COLUMN IF NOT EXISTS review_note text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'verification_submissions_evidence_type_check'
      AND conrelid = 'public.verification_submissions'::regclass
  ) THEN
    ALTER TABLE public.verification_submissions
      ADD CONSTRAINT verification_submissions_evidence_type_check
      CHECK (
        evidence_type IS NULL OR evidence_type IN (
          'site_observation',
          'provider_confirmation',
          'official_document',
          'photo_reference',
          'map_reference',
          'other'
        )
      );
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.verification_review_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES public.verification_submissions(id) ON DELETE RESTRICT,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  previous_status text,
  new_status text NOT NULL CHECK (new_status IN ('pending', 'approved', 'rejected')),
  review_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS verification_review_events_submission_created_idx
  ON public.verification_review_events (submission_id, created_at DESC);

ALTER TABLE public.verification_review_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS verification_review_events_admin_read
  ON public.verification_review_events;
CREATE POLICY verification_review_events_admin_read
  ON public.verification_review_events
  FOR SELECT TO authenticated
  USING (public.has_any_role(ARRAY['admin']::public.app_role[]));

CREATE OR REPLACE FUNCTION public.record_verification_review_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.review_status IS DISTINCT FROM OLD.review_status THEN
    INSERT INTO public.verification_review_events
      (submission_id, actor_id, previous_status, new_status, review_note)
    VALUES
      (NEW.id, COALESCE(auth.uid(), NEW.reviewed_by), OLD.review_status,
       NEW.review_status, NEW.review_note);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS verification_review_event_after_update
  ON public.verification_submissions;
CREATE TRIGGER verification_review_event_after_update
AFTER UPDATE OF review_status ON public.verification_submissions
FOR EACH ROW
EXECUTE FUNCTION public.record_verification_review_event();

COMMENT ON TABLE public.verification_review_events IS
  'Append-only audit history of verification submission status transitions.';
COMMENT ON COLUMN public.verification_submissions.evidence_reference IS
  'Optional URL or reference identifier for supporting evidence; do not store secrets or sensitive network details.';
COMMENT ON COLUMN public.verification_submissions.review_note IS
  'Administrator explanation recorded with the latest review decision.';
