-- SIGNAL360 Sprint 07: Location provenance
-- Adds traceability for building coordinates without changing existing building records.
-- Run once in Supabase SQL Editor for the SIGNAL360-Production project.

ALTER TABLE public.buildings
  ADD COLUMN IF NOT EXISTS location_source_type text,
  ADD COLUMN IF NOT EXISTS location_source text,
  ADD COLUMN IF NOT EXISTS location_updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS location_updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'buildings_location_source_type_check'
      AND conrelid = 'public.buildings'::regclass
  ) THEN
    ALTER TABLE public.buildings
      ADD CONSTRAINT buildings_location_source_type_check
      CHECK (
        location_source_type IS NULL
        OR location_source_type IN (
          'map_pin',
          'geocoder',
          'official_record',
          'field_survey',
          'other'
        )
      );
  END IF;
END
$$;

COMMENT ON COLUMN public.buildings.location_source_type IS
  'How the coordinate was obtained; this describes provenance, not verification.';
COMMENT ON COLUMN public.buildings.location_source IS
  'Human-readable source note or reference for the saved coordinates.';
COMMENT ON COLUMN public.buildings.location_updated_at IS
  'Timestamp when coordinate provenance was last saved.';
COMMENT ON COLUMN public.buildings.location_updated_by IS
  'Authenticated user who last saved the coordinate provenance.';

-- Existing coordinates and infrastructure statuses are intentionally untouched.
