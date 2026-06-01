-- Fix RLS policies to allow Providers to manage their Helpers
-- This allows the AuthService.providerCreateHelper() method to work correctly.

-- 1. Allow Providers to INSERT profiles for their helpers
DROP POLICY IF EXISTS "Providers can insert helpers" ON public.users;
CREATE POLICY "Providers can insert helpers" ON public.users 
FOR INSERT TO authenticated 
WITH CHECK (
  provider_id = auth.uid()::text 
  AND role = 'provider_helper'
);

-- 2. Allow Providers to UPDATE profiles for their helpers
DROP POLICY IF EXISTS "Providers can update their helpers" ON public.users;
CREATE POLICY "Providers can update their helpers" ON public.users 
FOR UPDATE TO authenticated 
USING (
  provider_id = auth.uid()::text 
  AND role = 'provider_helper'
);

-- 3. Ensure Providers can SELECT their helpers (update existing policy)
DROP POLICY IF EXISTS "Providers view their helpers" ON public.users;
CREATE POLICY "Providers view their helpers" ON public.users 
FOR SELECT TO authenticated 
USING (
  (auth.uid() = id) OR 
  (role = 'provider_helper' AND provider_id = auth.uid()::text)
);
