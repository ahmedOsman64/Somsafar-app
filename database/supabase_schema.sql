-- SomSafar Supabase Schema & Initial Setup

-- 1. Create Tables

-- USERS Table
CREATE TABLE IF NOT EXISTS public.users (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  role text DEFAULT 'traveler'::text CHECK (role IN ('traveler', 'provider', 'admin', 'provider_helper')),
  admin_role text CHECK (admin_role IN ('superAdmin', 'opsAdmin', 'financeAdmin', 'supportAdmin')),
  provider_type text CHECK (provider_type IN ('hotel', 'home', 'apartment', 'all', 'tour')),
  status text DEFAULT 'active'::text CHECK (status IN ('active', 'blocked', 'suspended')),
  phone text,
  location text,
  nationality text,
  date_of_birth timestamp with time zone,
  profile_image text,
  provider_id text,
  metadata jsonb DEFAULT '{}'::jsonb,
  last_session_id text,
  failed_attempts integer DEFAULT 0,
  last_login_attempt timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- SERVICES Table
CREATE TABLE IF NOT EXISTS public.services (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  title text NOT NULL,
  category text NOT NULL,
  description text,
  price numeric(10, 2) NOT NULL,
  location text NOT NULL,
  images text[] DEFAULT '{}'::text[],
  status text DEFAULT 'active'::text,
  metadata jsonb DEFAULT '{}'::jsonb,
  rating numeric(3, 2),
  reviews integer,
  is_verified boolean,
  discount numeric(5, 2),
  amenities text[],
  breakfast_price numeric(10, 2),
  airport_pickup_price numeric(10, 2),
  extra_bed_price numeric(10, 2),
  cleaning_price numeric(10, 2),
  early_check_in_price numeric(10, 2),
  late_check_out_price numeric(10, 2),
  created_at timestamp with time zone DEFAULT now() NOT NULL

);

-- BOOKINGS Table
CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  traveler_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  provider_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  service_id uuid REFERENCES public.services(id) ON DELETE CASCADE NOT NULL,
  service_title text,
  traveler_name text,
  status text DEFAULT 'pending'::text,
  check_in date,
  check_out date,
  guests integer DEFAULT 1,
  rooms integer DEFAULT 1,
  total_price numeric(10, 2) NOT NULL,
  contact_phone text,
  contact_email text,
  special_requests text,
  transaction_id text,
  payment_method text,
  payment_status text DEFAULT 'pending'::text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- CHATS Table
CREATE TABLE IF NOT EXISTS public.chats (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  sender_role text NOT NULL,
  message text NOT NULL,
  visible_to_traveler boolean DEFAULT true,
  is_internal_note boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- PAYMENTS Table
CREATE TABLE IF NOT EXISTS public.payments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE NOT NULL,
  user_name text NOT NULL,
  amount numeric(10, 2) NOT NULL,
  payment_method text NOT NULL,
  transaction_id text UNIQUE,
  status text DEFAULT 'pending'::text CHECK (status IN ('pending', 'successful', 'failed')),
  provider_id text, -- Scoping ID for providers
  provider_name text, -- Cache provider name
  payout_account text, -- Destination account
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- SUPPORT TICKETS Table
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  user_name text NOT NULL,
  user_email text NOT NULL,
  issue_type text NOT NULL,
  description text NOT NULL,
  status text DEFAULT 'open'::text,
  priority text DEFAULT 'medium'::text,
  messages jsonb DEFAULT '[]'::jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- BANNERS Table
CREATE TABLE IF NOT EXISTS public.banners (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  image_url text NOT NULL,
  caption text,
  display_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- REVIEWS Table
CREATE TABLE IF NOT EXISTS public.reviews (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  service_id uuid REFERENCES public.services(id) ON DELETE CASCADE NOT NULL,
  service_title text,
  traveler_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  traveler_name text,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_activities ENABLE ROW LEVEL SECURITY;

-- 3. HELPER FUNCTIONS

-- IMPROVED: Aggressively non-recursive admin check
-- We check jwt.claims directly if possible, or use a cached version.
-- The key is that this function MUST NOT query public.users when called from a public.users RLS policy.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
DECLARE
  _role text;
BEGIN
  -- 1. Bypass for service_role (always first)
  IF (current_setting('role', true) = 'service_role') THEN
    RETURN true;
  END IF;

  -- 2. Check JWT metadata first (Fastest, avoids table lookup)
  _role := (auth.jwt() -> 'user_metadata' ->> 'role');
  IF (_role = 'admin') THEN
    RETURN true;
  END IF;

  _role := (auth.jwt() -> 'app_metadata' ->> 'role');
  IF (_role = 'admin') THEN
    RETURN true;
  END IF;

  -- 3. Fallback: Direct table check (ONLY if not recursing)
  -- To prevent recursion, we only do this if we are NOT currently evaluating a policy on public.users
  -- However, since PL/pgSQL doesn't easily know the call stack, we use a custom GUC or just keep it simple.
  -- LATEST STRATEGY: RLS policies on 'users' will NOT use this function.
  
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() 
    AND role = 'admin' 
    AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. RLS POLICIES

-- === USERS ===
-- CRITICAL: These policies must NOT call is_admin() to avoid infinite recursion.
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.users;
CREATE POLICY "Public profiles are viewable by everyone." ON public.users FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile." ON public.users;
CREATE POLICY "Users can insert their own profile." ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile." ON public.users;
CREATE POLICY "Users can update own profile." ON public.users FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admin has full access to users." ON public.users;
CREATE POLICY "Admin has full access to users." ON public.users FOR ALL TO authenticated 
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  OR 
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- Travelers & Helpers can view provider profiles to see business/payment info
DROP POLICY IF EXISTS "Anyone can view provider profiles" ON public.users;
CREATE POLICY "Anyone can view provider profiles" ON public.users FOR SELECT TO authenticated 
USING (role = 'provider');

-- Provider & Helper Visibility
DROP POLICY IF EXISTS "Providers view their helpers" ON public.users;
CREATE POLICY "Providers view their helpers" ON public.users FOR SELECT TO authenticated 
USING (
  (auth.uid() = id) OR 
  (role = 'provider_helper' AND provider_id = auth.uid()::text)
);

DROP POLICY IF EXISTS "Helpers view their provider" ON public.users;
CREATE POLICY "Helpers view their provider" ON public.users FOR SELECT TO authenticated 
USING (
  (id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')) OR
  (role = 'provider_helper' AND provider_id = (auth.jwt() -> 'user_metadata' ->> 'provider_id'))
);

-- === SERVICES ===
DROP POLICY IF EXISTS "Anyone can view active services." ON public.services;
CREATE POLICY "Anyone can view active services." ON public.services FOR SELECT USING (status = 'active');

DROP POLICY IF EXISTS "Providers can view their own services" ON public.services;
CREATE POLICY "Providers can view their own services" ON public.services FOR SELECT USING (auth.uid() = provider_id);

DROP POLICY IF EXISTS "Providers can insert their own services" ON public.services;
CREATE POLICY "Providers can insert their own services" ON public.services FOR INSERT WITH CHECK (auth.uid() = provider_id);

DROP POLICY IF EXISTS "Providers can update their own services" ON public.services;
CREATE POLICY "Providers can update their own services" ON public.services FOR UPDATE USING (auth.uid() = provider_id);

DROP POLICY IF EXISTS "Providers can delete their own services" ON public.services;
CREATE POLICY "Providers can delete their own services" ON public.services FOR DELETE USING (auth.uid() = provider_id);

DROP POLICY IF EXISTS "Admin has full access to services" ON public.services;
CREATE POLICY "Admin has full access to services" ON public.services FOR ALL TO authenticated 
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  OR 
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  OR 
  public.is_admin()
);

-- === BOOKINGS ===
DROP POLICY IF EXISTS "Travelers view own bookings" ON public.bookings;
CREATE POLICY "Travelers view own bookings" ON public.bookings FOR SELECT USING (auth.uid() = traveler_id);

DROP POLICY IF EXISTS "Travelers create bookings" ON public.bookings;
CREATE POLICY "Travelers create bookings" ON public.bookings FOR INSERT WITH CHECK (auth.uid() = traveler_id);

DROP POLICY IF EXISTS "Travelers update own bookings" ON public.bookings;
CREATE POLICY "Travelers update own bookings" ON public.bookings FOR UPDATE USING (auth.uid() = traveler_id);

DROP POLICY IF EXISTS "Providers view bookings for their services" ON public.bookings;
CREATE POLICY "Providers view bookings for their services" ON public.bookings FOR SELECT USING (auth.uid() = provider_id);

DROP POLICY IF EXISTS "Providers update bookings for their services" ON public.bookings;
CREATE POLICY "Providers update bookings for their services" ON public.bookings FOR UPDATE USING (auth.uid() = provider_id);

DROP POLICY IF EXISTS "Admin has full access to bookings" ON public.bookings;
CREATE POLICY "Admin has full access to bookings" ON public.bookings FOR ALL TO authenticated USING (public.is_admin());

-- === CHATS ===
DROP POLICY IF EXISTS "Travelers view visible chats for their bookings" ON public.chats;
CREATE POLICY "Travelers view visible chats for their bookings" ON public.chats FOR SELECT USING (
  visible_to_traveler = true AND EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id AND traveler_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Travelers send messages to their bookings" ON public.chats;
CREATE POLICY "Travelers send messages to their bookings" ON public.chats FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id AND traveler_id = auth.uid()
  ) AND auth.uid() = sender_id
);

DROP POLICY IF EXISTS "Providers view all chats for their bookings" ON public.chats;
CREATE POLICY "Providers view all chats for their bookings" ON public.chats FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id AND provider_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Providers send messages to their bookings" ON public.chats;
CREATE POLICY "Providers send messages to their bookings" ON public.chats FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id AND provider_id = auth.uid()
  ) AND auth.uid() = sender_id
);

DROP POLICY IF EXISTS "Admin has full access to chats" ON public.chats;
CREATE POLICY "Admin has full access to chats" ON public.chats FOR ALL TO authenticated USING (public.is_admin());

-- === PAYMENTS ===
DROP POLICY IF EXISTS "Travelers view payments for their bookings" ON public.payments;
CREATE POLICY "Travelers view payments for their bookings" ON public.payments FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND traveler_id = auth.uid())
);

DROP POLICY IF EXISTS "Providers view payments for their bookings" ON public.payments;
CREATE POLICY "Providers view payments for their bookings" ON public.payments FOR SELECT USING (
  auth.uid()::text = provider_id OR
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND provider_id = auth.uid())
);

DROP POLICY IF EXISTS "Users can insert payments" ON public.payments;
CREATE POLICY "Users can insert payments" ON public.payments FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Admin has full access to payments" ON public.payments;
CREATE POLICY "Admin has full access to payments" ON public.payments FOR ALL TO authenticated USING (public.is_admin());

-- === SUPPORT TICKETS ===
DROP POLICY IF EXISTS "Users view own tickets" ON public.support_tickets;
CREATE POLICY "Users view own tickets" ON public.support_tickets FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users create tickets" ON public.support_tickets;
CREATE POLICY "Users create tickets" ON public.support_tickets FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin has full access to tickets" ON public.support_tickets;
CREATE POLICY "Admin has full access to tickets" ON public.support_tickets FOR ALL TO authenticated USING (public.is_admin());

-- === REVIEWS ===
DROP POLICY IF EXISTS "Anyone can view reviews." ON public.reviews;
CREATE POLICY "Anyone can view reviews." ON public.reviews FOR SELECT USING (true);

DROP POLICY IF EXISTS "Travelers can insert their own reviews." ON public.reviews;
CREATE POLICY "Travelers can insert their own reviews." ON public.reviews FOR INSERT WITH CHECK (auth.uid() = traveler_id);

DROP POLICY IF EXISTS "Admin has full access to reviews" ON public.reviews;
CREATE POLICY "Admin has full access to reviews" ON public.reviews FOR ALL TO authenticated USING (public.is_admin());

-- === BANNERS ===
DROP POLICY IF EXISTS "Anyone can view banners" ON public.banners;
CREATE POLICY "Anyone can view banners" ON public.banners FOR SELECT USING (active = true);

DROP POLICY IF EXISTS "Admin has full access to banners" ON public.banners;
CREATE POLICY "Admin has full access to banners" ON public.banners FOR ALL TO authenticated USING (public.is_admin());

-- 4. AUTOMATIC PROFILE CREATION
-- This trigger automatically creates a profile in public.users when a new user signs up via Supabase Auth.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, name, email, role, admin_role, provider_type, phone, location, provider_id, status, metadata, created_at, updated_at)
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

-- Trigger the function every time a user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. INITIAL ADMIN USER (run this in Supabase SQL editor manually if needed)
-- This creates a superadmin user IF they don't already exist.
-- To actually log in, you must still create the user in auth.users first.
/*
INSERT INTO public.users (id, name, email, role, admin_role, status)
VALUES (
  'YOUR_AUTH_USER_ID', 
  'Admin Name', 
  'admin@example.com', 
  'admin', 
  'superAdmin', 
  'active'
) ON CONFLICT (id) DO NOTHING;
*/

-- 6. SYSTEM ACTIVITIES Table (Persistent Logs)
CREATE TABLE IF NOT EXISTS public.system_activities (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL,
  subtitle text NOT NULL,
  type text NOT NULL,
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL, -- Preserve log even if user is deleted
  user_name text, -- Keep name even if user is deleted (but cascade will remove row if user deleted)
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.system_activities ENABLE ROW LEVEL SECURITY;

-- Admin Policy for Activities
DROP POLICY IF EXISTS "Admin can view all activities" ON public.system_activities;
CREATE POLICY "Admin can view all activities" ON public.system_activities 
FOR SELECT TO authenticated 
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  OR 
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- Policy to allow the system (via function) to insert
DROP POLICY IF EXISTS "System can insert activities" ON public.system_activities;
CREATE POLICY "System can insert activities" ON public.system_activities 
FOR INSERT TO authenticated 
WITH CHECK (true);

-- 7. ACCOUNT DELETION FUNCTION
-- This function allows a user to delete their own account.
-- It logs the activity before deleting the user from auth.users.
CREATE OR REPLACE FUNCTION public.delete_user_self(reason text DEFAULT NULL)
RETURNS void AS $$
DECLARE
  _user_id uuid := auth.uid();
  _user_name text;
BEGIN
  -- 1. Check if user is authenticated
  IF _user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2. Get user name before deleting (from public.users)
  SELECT name INTO _user_name FROM public.users WHERE id = _user_id;
  
  -- 3. Log the deletion event to system_activities
  INSERT INTO public.system_activities (title, subtitle, type, user_name, metadata)
  VALUES (
    'Account Deleted: ' || COALESCE(_user_name, 'Unknown'),
    COALESCE(_user_name, 'Unknown') || ' has deleted their account. Reason: ' || COALESCE(reason, 'Not specified'),
    'userDeletion',
    _user_name,
    jsonb_build_object(
      'deleted_user_id', _user_id,
      'reason', reason,
      'deletion_time', now()
    )
  );
  
  -- 4. Delete the user from auth.users
  -- NOTE: This requires the function to be SECURITY DEFINER and 
  -- the user to have permission to delete from auth.users.
  DELETE FROM auth.users WHERE id = _user_id;

EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Failed to delete account: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 8. TAXES Table
CREATE TABLE IF NOT EXISTS public.taxes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  provider_type text NOT NULL CHECK (provider_type IN ('hotel', 'home', 'apartment', 'all', 'tour')),
  tax_type text NOT NULL CHECK (tax_type IN ('percentage', 'fixed')),
  rate numeric(10, 2) NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.taxes ENABLE ROW LEVEL SECURITY;

-- 9. NOTIFICATIONS Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL,
  is_read boolean DEFAULT false,
  data jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Policies for TAXES
DROP POLICY IF EXISTS "Anyone can view active taxes" ON public.taxes;
CREATE POLICY "Anyone can view active taxes" ON public.taxes 
FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Admin has full access to taxes" ON public.taxes;
CREATE POLICY "Admin has full access to taxes" ON public.taxes 
FOR ALL TO authenticated 
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  OR 
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- Policies for NOTIFICATIONS
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications 
FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications 
FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications" ON public.notifications 
FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;
CREATE POLICY "System can insert notifications" ON public.notifications 
FOR INSERT WITH CHECK (true);

-- 10. HELPER ACCESS POLICIES
-- These allow provider helpers to access their parent provider's data

-- Services
CREATE POLICY "Helpers can view provider services" ON public.services FOR SELECT TO authenticated 
USING (provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id'));

CREATE POLICY "Helpers can manage provider services" ON public.services FOR ALL TO authenticated 
USING (provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id'));

-- Bookings
CREATE POLICY "Helpers can view provider bookings" ON public.bookings FOR SELECT TO authenticated 
USING (provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id'));

CREATE POLICY "Helpers can manage provider bookings" ON public.bookings FOR ALL TO authenticated 
USING (provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id'));

-- Chats
CREATE POLICY "Helpers can view provider chats" ON public.chats FOR SELECT TO authenticated 
USING (EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')));

CREATE POLICY "Helpers can send provider chats" ON public.chats FOR INSERT TO authenticated 
WITH CHECK (EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')) AND auth.uid() = sender_id);

-- Payments
DROP POLICY IF EXISTS "Helpers can view provider payments" ON public.payments;
CREATE POLICY "Helpers can view provider payments" ON public.payments FOR SELECT TO authenticated 
USING (
  provider_id = (auth.jwt() -> 'user_metadata' ->> 'provider_id') OR
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id'))
);
