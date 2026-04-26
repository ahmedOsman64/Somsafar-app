-- FIX FOR HELPER ACCOUNT CREATION
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)

-- 1. Update the role constraint to allow 'provider_helper'
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('traveler', 'provider', 'admin', 'provider_helper'));

-- 2. Ensure provider_id column exists
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS provider_id text;

-- 3. Fix the handle_new_user() trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (
    id, 
    name, 
    email, 
    role, 
    admin_role, 
    provider_type, 
    phone, 
    location, 
    provider_id, 
    status, 
    metadata, 
    created_at, 
    updated_at
  )
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'name', 'New User'),
    new.email,
    COALESCE(new.raw_user_meta_data->>'role', 'traveler'),
    new.raw_user_meta_data->>'admin_role',
    new.raw_user_meta_data->>'provider_type',
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'location',
    new.raw_user_meta_data->>'provider_id',
    'active',
    '{}'::jsonb,
    now(),
    now()
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Add RLS Policies for Providers to manage their Helpers
DROP POLICY IF EXISTS "Providers can view their own helpers" ON public.users;
CREATE POLICY "Providers can view their own helpers" ON public.users 
FOR SELECT TO authenticated 
USING (
  provider_id = auth.uid()::text
);

DROP POLICY IF EXISTS "Providers can delete their own helpers" ON public.users;
CREATE POLICY "Providers can delete their own helpers" ON public.users 
FOR DELETE TO authenticated 
USING (
  provider_id = auth.uid()::text
);

-- ADDED: INSERT policy for Providers to create helpers
DROP POLICY IF EXISTS "Providers can insert their own helpers" ON public.users;
CREATE POLICY "Providers can insert their own helpers" ON public.users 
FOR INSERT TO authenticated 
WITH CHECK (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'provider'
  AND provider_id = auth.uid()::text
  AND role = 'provider_helper'
);

-- ADDED: UPDATE policy for Providers to manage helpers
DROP POLICY IF EXISTS "Providers can update their own helpers" ON public.users;
CREATE POLICY "Providers can update their own helpers" ON public.users 
FOR UPDATE TO authenticated 
USING (
  provider_id = auth.uid()::text
) WITH CHECK (
  provider_id = auth.uid()::text
);


-- 5. Helper Access Rules for Services
DROP POLICY IF EXISTS "Helpers can view provider services" ON public.services;
CREATE POLICY "Helpers can view provider services" ON public.services 
FOR SELECT TO authenticated 
USING (
  provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
);

DROP POLICY IF EXISTS "Helpers can manage provider services" ON public.services;
CREATE POLICY "Helpers can manage provider services" ON public.services 
FOR ALL TO authenticated 
USING (
  provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
);

-- 6. Helper Access Rules for Bookings
DROP POLICY IF EXISTS "Helpers can view provider bookings" ON public.bookings;
CREATE POLICY "Helpers can view provider bookings" ON public.bookings 
FOR SELECT TO authenticated 
USING (
  provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
);

DROP POLICY IF EXISTS "Helpers can manage provider bookings" ON public.bookings;
CREATE POLICY "Helpers can manage provider bookings" ON public.bookings 
FOR ALL TO authenticated 
USING (
  provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
);

-- 7. Helper Access Rules for Chats
DROP POLICY IF EXISTS "Helpers can view provider chats" ON public.chats;
CREATE POLICY "Helpers can view provider chats" ON public.chats 
FOR SELECT TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id 
    AND provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
  )
);

DROP POLICY IF EXISTS "Helpers can send provider chats" ON public.chats;
CREATE POLICY "Helpers can send provider chats" ON public.chats 
FOR INSERT TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id 
    AND provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
  ) AND auth.uid() = sender_id
);

-- 8. Helper Access Rules for Payments
DROP POLICY IF EXISTS "Helpers can view provider payments" ON public.payments;
CREATE POLICY "Helpers can view provider payments" ON public.payments 
FOR SELECT TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id 
    AND provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
  )
);
