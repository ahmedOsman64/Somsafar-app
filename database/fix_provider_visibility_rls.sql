-- Fix RLS: Allow Travelers and other Authenticated users to view Provider profiles.
-- This ensures that during booking and payment, travelers can see the provider's
-- bank details, phone, and name. This also enables Real-time updates for these profiles.

-- 1. Drop the existing overly-restrictive profile viewing policy
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.users;

-- 2. Create a new policy that allows:
--    a) Users to see their own profile (any role)
--    b) Any authenticated user to see 'provider' or 'provider_helper' profiles
CREATE POLICY "Users can view own and provider profiles" ON public.users
FOR SELECT TO authenticated
USING (
  auth.uid() = id 
  OR role = 'provider' 
  OR role = 'provider_helper'
  OR public.is_admin()
);

-- 3. Ensure the 'admin' has full access regardless (already exists but good as safety)
DROP POLICY IF EXISTS "Admin has full access to users." ON public.users;
CREATE POLICY "Admin has full access to users." ON public.users
FOR ALL TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  OR 
  public.is_admin()
);

-- 4. Enable Realtime for the users table
-- This is CRITICAL for the .stream() logic in the Flutter app to work.
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;

-- Note: This change allows travelers to receive real-time updates for any provider's row
-- they have fetched, satisfying the requirement for automatic updates.
