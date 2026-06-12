-- SomSafar: Fix Insecure RLS Policies
-- This script migrates from user_metadata to secure database/app_metadata checks.

-- 1. Redefine is_admin() safely
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  -- Service role (Super Admin) always has access
  IF (current_setting('role', true) = 'service_role') THEN RETURN true; END IF;
  
  -- Check app_metadata (set by system, not user-editable)
  IF (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin' THEN RETURN true; END IF;
  
  -- Check public.users table (source of truth)
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() 
    AND role = 'admin' 
    AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Update USERS policy
DROP POLICY IF EXISTS "Users can view own and provider profiles" ON public.users;
CREATE POLICY "Users can view own and provider profiles" ON public.users
FOR SELECT TO authenticated
USING (
  auth.uid() = id 
  OR role = 'provider' 
  OR role = 'provider_helper'
  OR public.is_admin()
);

-- 3. Update BOOKINGS policy (Fix for Provider Helpers)
DROP POLICY IF EXISTS "Providers view own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Helpers view own bookings" ON public.bookings;

CREATE POLICY "Providers view own bookings" ON public.bookings 
FOR SELECT USING (
  auth.uid() = provider_id 
  OR provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid()) OR public.is_admin()
);

-- 4. Update CHATS policy
DROP POLICY IF EXISTS "Users can view chats for their bookings" ON public.chats;
CREATE POLICY "Users can view chats for their bookings" ON public.chats 
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id 
    AND (
      traveler_id = auth.uid() 
      OR provider_id = auth.uid() 
      OR provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())
      OR public.is_admin()
    )
  )
);

-- 5. Update PAYMENTS policy
DROP POLICY IF EXISTS "Helpers view own payments" ON public.payments;
CREATE POLICY "Helpers view own payments" ON public.payments 
FOR SELECT USING (
  provider_id = (SELECT provider_id FROM public.users WHERE id = auth.uid()) OR
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())) OR
  public.is_admin()
);

-- 6. Ensure RLS is enabled (safety check)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- Note: After running this, the linter errors for "RLS references user metadata" 
-- on these tables should disappear.
