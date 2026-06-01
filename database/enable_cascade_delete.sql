-- SQL to enable automatic "DELETE CASCADE" for all user data
-- Run this in Supabase SQL Editor

-- 1. Ensure reviews table exists with cascade
CREATE TABLE IF NOT EXISTS public.reviews (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  service_id uuid REFERENCES public.services(id) ON DELETE CASCADE NOT NULL,
  traveler_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  rating integer,
  comment text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. Update system_activities to cascade (if it was created without link)
-- First, add the constraint if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'system_activities_user_id_fkey') THEN
        ALTER TABLE public.system_activities 
        ADD CONSTRAINT system_activities_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    ELSE
        ALTER TABLE public.system_activities 
        DROP CONSTRAINT system_activities_user_id_fkey,
        ADD CONSTRAINT system_activities_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 3. Verify other main tables for CASCADE
-- (Note: ALTER TABLE script to ensure OND DELETE CASCADE is active)

-- Bookings
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_traveler_id_fkey;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_traveler_id_fkey FOREIGN KEY (traveler_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_provider_id_fkey;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Services
ALTER TABLE public.services DROP CONSTRAINT IF EXISTS services_provider_id_fkey;
ALTER TABLE public.services ADD CONSTRAINT services_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Chats
ALTER TABLE public.chats DROP CONSTRAINT IF EXISTS chats_sender_id_fkey;
ALTER TABLE public.chats ADD CONSTRAINT chats_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Profile Link (CRITICAL)
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_id_fkey;
ALTER TABLE public.users ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

PRINT 'Cascade deletion is now fully active for all user data.';
