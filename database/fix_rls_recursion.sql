-- SomSafar: Fix Infinite RLS Recursion
-- This script replaces recursive subqueries in RLS policies with safe SECURITY DEFINER functions.

-- 1. Safe Helper Functions (Bypass RLS)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_my_provider_id()
RETURNS text AS $$
  SELECT provider_id FROM public.users WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- 2. Improved Safe Admin Check
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  -- Service role (Super Admin) always has access
  IF (current_setting('role', true) = 'service_role') THEN RETURN true; END IF;
  
  -- Check app_metadata (set by system, most efficient)
  IF (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin' THEN RETURN true; END IF;
  
  -- Fallback to users table via safe helper
  RETURN (public.get_my_role() = 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. FIX: public.users policies (Remove all recursive subqueries)
-- First, drop ALL possible policy names for the users table to avoid conflicts
DROP POLICY IF EXISTS "Users can view own and provider profiles" ON public.users;
DROP POLICY IF EXISTS "Anyone can view provider profiles" ON public.users;
DROP POLICY IF EXISTS "Admin has full access to users." ON public.users;
DROP POLICY IF EXISTS "Admin has full access to users" ON public.users;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.users;
DROP POLICY IF EXISTS "Providers view their helpers" ON public.users;
DROP POLICY IF EXISTS "Helpers view their provider" ON public.users;
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Public can view providers" ON public.users;
DROP POLICY IF EXISTS "Helpers and Providers linked visibility" ON public.users;

-- Standard users see themselves
CREATE POLICY "Users can view own profile" ON public.users 
FOR SELECT TO authenticated 
USING (auth.uid() = id);

-- Everyone can see providers (needed for booking/search)
CREATE POLICY "Public can view providers" ON public.users 
FOR SELECT TO authenticated 
USING (role = 'provider');

-- Helpers/Providers see each other
CREATE POLICY "Helpers and Providers linked visibility" ON public.users 
FOR SELECT TO authenticated 
USING (
  provider_id = (SELECT public.get_my_provider_id()) -- Safe non-recursive check
  OR (role = 'provider' AND id::text = (SELECT public.get_my_provider_id()))
);

-- Admin full access
CREATE POLICY "Admin has full access to users" ON public.users 
FOR ALL TO authenticated 
USING (public.is_admin());

-- 4. FIX: public.bookings policies
DROP POLICY IF EXISTS "Helpers view own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Admin full access to all" ON public.bookings;
CREATE POLICY "Helpers view own bookings" ON public.bookings 
FOR SELECT TO authenticated 
USING (
  provider_id::text = (SELECT public.get_my_provider_id()) 
  OR public.is_admin()
);

-- 5. FIX: public.payments policies
DROP POLICY IF EXISTS "Helpers view own payments" ON public.payments;
CREATE POLICY "Helpers view own payments" ON public.payments 
FOR SELECT TO authenticated 
USING (
  provider_id = (SELECT public.get_my_provider_id()) 
  OR public.is_admin()
);

-- 6. FIX: public.chats policies
DROP POLICY IF EXISTS "Helpers view own chats" ON public.chats;
CREATE POLICY "Helpers view own chats" ON public.chats 
FOR SELECT TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id 
    AND provider_id::text = (SELECT public.get_my_provider_id())
  ) 
  OR public.is_admin()
);

-- 7. Ensure RLS is enabled
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- Note: After running this, the "Unable to load profile" error caused by recursion should be resolved.
