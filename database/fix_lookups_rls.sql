-- Fix RLS policies for lookups table to allow seeding from the client
-- This script adds INSERT and UPDATE policies for authenticated users.

-- 1. Ensure RLS is enabled
ALTER TABLE public.lookups ENABLE ROW LEVEL SECURITY;

-- 2. Allow anyone to view active lookups (already exists, but ensuring)
DROP POLICY IF EXISTS "Anyone can view lookups" ON public.lookups;
CREATE POLICY "Anyone can view lookups" ON public.lookups 
FOR SELECT 
USING (is_active = true);

-- 3. Allow authenticated users to insert new lookups
-- WARNING: In a production environment, you might want to restrict this to admin roles.
DROP POLICY IF EXISTS "Authenticated users can insert lookups" ON public.lookups;
CREATE POLICY "Authenticated users can insert lookups" ON public.lookups 
FOR INSERT 
TO authenticated 
WITH CHECK (true);

-- 4. Allow authenticated users to update existing lookups
DROP POLICY IF EXISTS "Authenticated users can update lookups" ON public.lookups;
CREATE POLICY "Authenticated users can update lookups" ON public.lookups 
FOR UPDATE 
TO authenticated 
USING (true)
WITH CHECK (true);

-- 5. Optional: If you want to allow ANONYMOUS seeding (during development), uncomment below:
/*
DROP POLICY IF EXISTS "Anon can insert lookups" ON public.lookups;
CREATE POLICY "Anon can insert lookups" ON public.lookups 
FOR INSERT 
TO anon 
WITH CHECK (true);

DROP POLICY IF EXISTS "Anon can update lookups" ON public.lookups;
CREATE POLICY "Anon can update lookups" ON public.lookups 
FOR UPDATE 
TO anon 
USING (true)
WITH CHECK (true);
*/
