-- SomSafar Secure RLS Migration
-- FIX: Replaces insecure user_metadata references with secure database lookups.
-- This script fixes the "Providers can insert their own helpers" policy and others.

-- 1. Ensure a secure is_admin() function exists
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  -- Service role (Super Admin) always has access
  IF (current_setting('role', true) = 'service_role') THEN RETURN true; END IF;
  
  -- Check public.users table (source of truth)
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() 
    AND role = 'admin' 
    AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. FIX: "Providers can insert their own helpers" on public.users
-- Previous policy used (auth.jwt() -> 'user_metadata' ->> 'role') = 'provider' which is insecure.
DROP POLICY IF EXISTS "Providers can insert their own helpers" ON public.users;
CREATE POLICY "Providers can insert their own helpers" ON public.users 
FOR INSERT TO authenticated 
WITH CHECK (
  (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role = 'provider'
    )
    OR public.is_admin()
  )
  AND provider_id = auth.uid()::text
  AND role = 'provider_helper'
);

-- 3. FIX: Services policies (Helpers and Providers)
DROP POLICY IF EXISTS "Helpers can view provider services" ON public.services;
CREATE POLICY "Helpers can view provider services" ON public.services 
FOR SELECT TO authenticated 
USING (
  provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())
  OR provider_id::text = auth.uid()::text
  OR public.is_admin()
);

DROP POLICY IF EXISTS "Helpers can manage provider services" ON public.services;
CREATE POLICY "Helpers can manage provider services" ON public.services 
FOR ALL TO authenticated 
USING (
  provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())
  OR provider_id::text = auth.uid()::text
  OR public.is_admin()
);

-- 4. FIX: Bookings policies
DROP POLICY IF EXISTS "Helpers can view provider bookings" ON public.bookings;
CREATE POLICY "Helpers can view provider bookings" ON public.bookings 
FOR SELECT TO authenticated 
USING (
  provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())
  OR provider_id::text = auth.uid()::text
  OR public.is_admin()
);

DROP POLICY IF EXISTS "Helpers can manage provider bookings" ON public.bookings;
CREATE POLICY "Helpers can manage provider bookings" ON public.bookings 
FOR ALL TO authenticated 
USING (
  provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())
  OR provider_id::text = auth.uid()::text
  OR public.is_admin()
);

-- 5. FIX: Chats policies
DROP POLICY IF EXISTS "Helpers can view provider chats" ON public.chats;
CREATE POLICY "Helpers can view provider chats" ON public.chats 
FOR SELECT TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id 
    AND (
      provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())
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
        provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())
        OR provider_id::text = auth.uid()::text
      )
    ) 
    AND auth.uid() = sender_id
  )
  OR public.is_admin()
);

-- 6. FIX: Payments policies
DROP POLICY IF EXISTS "Helpers can view provider payments" ON public.payments;
CREATE POLICY "Helpers can view provider payments" ON public.payments 
FOR SELECT TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id 
    AND (
      provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())
      OR provider_id::text = auth.uid()::text
    )
  )
  OR public.is_admin()
);

-- 7. Verification check (Optional but recommended)
-- Ensure RLS is actually enabled on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
