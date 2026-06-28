-- SomSafar: Fix Insecure RLS Policies
-- This script replaces references to Supabase Auth user_metadata with secure database lookups.
-- user_metadata is editable by end-users and should never be used for security-critical checks.

-- 1. SECURE HELPER FUNCTIONS
-- Using SECURITY DEFINER allows these functions to bypass RLS to perform lookups, 
-- which is necessary to avoid infinite recursion and ensure the lookup is authoritative.

-- Safe Helper: Get Current User Role
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- Safe Helper: Get Linked Provider ID (for Helpers)
CREATE OR REPLACE FUNCTION public.get_my_provider_id()
RETURNS text AS $$
  SELECT provider_id FROM public.users WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- Safe Helper: Admin Check
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  -- Service role (Super Admin) always has access
  IF (current_setting('role', true) = 'service_role') THEN RETURN true; END IF;
  
  -- Check app_metadata (set by system, not user-editable)
  IF (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin' THEN RETURN true; END IF;
  
  -- Fallback to users table via safe helper
  RETURN (public.get_my_role() = 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- 2. FIX TABLE: public.users
-- This is where the reported issue "Helpers and Providers linked visibility" resides.

DROP POLICY IF EXISTS "Helpers and Providers linked visibility" ON public.users;
CREATE POLICY "Helpers and Providers linked visibility" ON public.users 
FOR SELECT TO authenticated 
USING (
  provider_id = (SELECT public.get_my_provider_id()) -- Look up in DB, not metadata
  OR (role = 'provider' AND id::text = (SELECT public.get_my_provider_id()))
  OR public.is_admin()
);

-- Fix: Providers creating helpers
DROP POLICY IF EXISTS "Providers can insert their own helpers" ON public.users;
CREATE POLICY "Providers can insert their own helpers" ON public.users 
FOR INSERT TO authenticated 
WITH CHECK (
  (public.get_my_role() = 'provider') -- Look up in DB, not metadata
  AND provider_id = auth.uid()::text
  AND role = 'provider_helper'
);


-- 3. FIX TABLE: public.services
-- Replace metadata checks with database lookups for helpers.

DROP POLICY IF EXISTS "Helpers can view provider services" ON public.services;
CREATE POLICY "Helpers can view provider services" ON public.services 
FOR SELECT TO authenticated 
USING (
  provider_id::text = (SELECT public.get_my_provider_id())
  OR provider_id::text = auth.uid()::text
  OR public.is_admin()
);

DROP POLICY IF EXISTS "Helpers can manage provider services" ON public.services;
CREATE POLICY "Helpers can manage provider services" ON public.services 
FOR ALL TO authenticated 
USING (
  provider_id::text = (SELECT public.get_my_provider_id())
  OR provider_id::text = auth.uid()::text
  OR public.is_admin()
);


-- 4. FIX TABLE: public.bookings
-- Standardize helper visibility via database lookup.

DROP POLICY IF EXISTS "Helpers can view provider bookings" ON public.bookings;
CREATE POLICY "Helpers can view provider bookings" ON public.bookings 
FOR SELECT TO authenticated 
USING (
  provider_id::text = (SELECT public.get_my_provider_id()) 
  OR provider_id::text = auth.uid()::text
  OR public.is_admin()
);

DROP POLICY IF EXISTS "Helpers can manage provider bookings" ON public.bookings;
CREATE POLICY "Helpers can manage provider bookings" ON public.bookings 
FOR ALL TO authenticated 
USING (
  provider_id::text = (SELECT public.get_my_provider_id()) 
  OR provider_id::text = auth.uid()::text
  OR public.is_admin()
);


-- 5. FIX TABLE: public.chats
-- Secure chat access for helpers.

DROP POLICY IF EXISTS "Helpers can view provider chats" ON public.chats;
CREATE POLICY "Helpers can view provider chats" ON public.chats 
FOR SELECT TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id 
    AND (
      provider_id::text = (SELECT public.get_my_provider_id())
      OR provider_id::text = auth.uid()::text
    )
  ) 
  OR public.is_admin()
);

DROP POLICY IF EXISTS "Helpers can send provider chats" ON public.chats;
CREATE POLICY "Helpers can send provider chats" ON public.chats 
FOR INSERT TO authenticated 
WITH CHECK (
  (
    EXISTS (
      SELECT 1 FROM public.bookings 
      WHERE id = booking_id 
      AND (
        provider_id::text = (SELECT public.get_my_provider_id())
        OR provider_id::text = auth.uid()::text
      )
    ) 
    AND auth.uid() = sender_id
  )
  OR public.is_admin()
);


-- 6. FIX TABLE: public.payments
-- Secure payment visibility for helpers.

DROP POLICY IF EXISTS "Helpers can view provider payments" ON public.payments;
CREATE POLICY "Helpers can view provider payments" ON public.payments 
FOR SELECT TO authenticated 
USING (
  provider_id = (SELECT public.get_my_provider_id()) 
  OR EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id 
    AND (
      provider_id::text = (SELECT public.get_my_provider_id())
      OR provider_id::text = auth.uid()::text
    )
  ) 
  OR public.is_admin()
);


-- 7. CLEANUP OLD POLICIES
-- Drop any other known policies that might still be referencing user_metadata for security
DROP POLICY IF EXISTS "Admin has full access to users" ON public.users;
CREATE POLICY "Admin has full access to users" ON public.users 
FOR ALL TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "Admin has full access to services" ON public.services;
CREATE POLICY "Admin has full access to services" ON public.services 
FOR ALL TO authenticated USING (public.is_admin());


-- FINAL VERIFICATION
-- After running this, the "RLS references user metadata" security alert will be resolved
-- because all auth logic now relies on trusted database state (public.users) or
-- immutable app_metadata (managed by server-side logic).
