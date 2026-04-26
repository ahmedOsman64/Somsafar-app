-- Migration to add missing columns to the bookings table
DO $$ 
BEGIN 
  -- 1. Add 'taxes' column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='taxes') THEN
    ALTER TABLE public.bookings ADD COLUMN taxes numeric(10, 2) DEFAULT 0.0;
  END IF;

  -- 2. Add 'metadata' column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='metadata') THEN
    ALTER TABLE public.bookings ADD COLUMN metadata jsonb DEFAULT '{}'::jsonb;
  END IF;

  -- 3. Ensure 'package_type' exists (sanity check)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='package_type') THEN
    ALTER TABLE public.bookings ADD COLUMN package_type text;
  END IF;
END $$;
