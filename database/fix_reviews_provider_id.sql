-- Migration: Add provider_id to reviews table
-- This allows direct filtering by provider_id and enables cleaner RLS policies

-- 1. Add the column
ALTER TABLE public.reviews 
ADD COLUMN IF NOT EXISTS provider_id uuid REFERENCES public.users(id) ON DELETE CASCADE;

-- 2. Populate existing reviews with provider_id from the related service
UPDATE public.reviews r
SET provider_id = s.provider_id
FROM public.services s
WHERE r.service_id = s.id;

-- 3. Make the column NOT NULL after populating (optional but recommended for data integrity)
-- ALTER TABLE public.reviews ALTER COLUMN provider_id SET NOT NULL;

-- 4. Update RLS Policies for Providers
-- Allow providers to see reviews for their own services
DROP POLICY IF EXISTS "Providers can see their own reviews" ON public.reviews;
CREATE POLICY "Providers can see their own reviews" ON public.reviews 
FOR SELECT TO authenticated 
USING (
  auth.uid() = provider_id OR 
  provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
);

-- Note: Ensure is_admin() and admin policies still work as defined in supabase_schema.sql
