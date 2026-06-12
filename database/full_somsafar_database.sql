-- SomSafar Full Database Schema & Initial Setup
-- This file consolidates all tables, functions, triggers, and RLS policies.
-- Date: June 2026

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. TABLES

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
  encrypted_phone bytea,
  location text,
  nationality text,
  date_of_birth timestamp with time zone,
  profile_image text,
  provider_id text, -- Used for provider_helpers to link to their provider
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
  max_guests integer,
  available_slots integer DEFAULT 1,
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
  taxes numeric(10, 2) DEFAULT 0,
  contact_phone text,
  contact_email text,
  special_requests text,
  transaction_id text,
  payment_method text,
  payment_status text DEFAULT 'pending'::text,
  package_type text, -- Added for specialized tours
  package_id uuid, -- Reference to booking_packages
  metadata jsonb DEFAULT '{}'::jsonb,
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

-- SYSTEM ACTIVITIES Table
CREATE TABLE IF NOT EXISTS public.system_activities (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL,
  subtitle text NOT NULL,
  type text NOT NULL,
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  user_name text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- TAXES Table
CREATE TABLE IF NOT EXISTS public.taxes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  provider_type text NOT NULL CHECK (provider_type IN ('hotel', 'home', 'apartment', 'all', 'tour')),
  tax_type text NOT NULL CHECK (tax_type IN ('percentage', 'fixed')),
  rate numeric(10, 2) NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- NOTIFICATIONS Table
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

-- TRAVELERS Table (for group bookings)
CREATE TABLE IF NOT EXISTS public.travelers (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  age integer NOT NULL,
  gender text NOT NULL,
  passport text,
  encrypted_passport bytea,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- BOOKING PACKAGES Table
CREATE TABLE IF NOT EXISTS public.booking_packages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  type text NOT NULL CHECK (type IN ('jumma', 'eid', 'custom')),
  name text NOT NULL,
  description text,
  price numeric(10, 2) NOT NULL,
  services text[] DEFAULT '{}'::text[],
  location text NOT NULL,
  max_people integer,
  available_slots integer,
  images text[] DEFAULT '{}'::text[],
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- BOOKING DETAILS Table
CREATE TABLE IF NOT EXISTS public.booking_details (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE NOT NULL,
  key text NOT NULL,
  value text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- LOOKUPS Table
CREATE TABLE IF NOT EXISTS public.lookups (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  category text NOT NULL,
  key text NOT NULL,
  label text NOT NULL,
  icon text,
  metadata jsonb DEFAULT '{}'::jsonb,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  UNIQUE(category, key)
);

-- SYSTEM SETTINGS Table
CREATE TABLE IF NOT EXISTS public.system_settings (
  key text PRIMARY KEY,
  value jsonb,
  description text,
  updated_at timestamp with time zone DEFAULT now()
);

-- REQUEST LOGS Table (Rate Limiting)
CREATE TABLE IF NOT EXISTS public.request_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  ip_address text,
  endpoint text,
  created_at timestamp with time zone DEFAULT now()
);

-- 2. HELPER FUNCTIONS

-- Admin Check Function
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

-- Automatic Profile Creation Function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, name, email, role, admin_role, provider_type, phone, location, provider_id, status, metadata)
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
    '{}'::jsonb
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Safe Booking Function (with concurrency control)
CREATE OR REPLACE FUNCTION public.create_booking_safe(
  p_booking_id uuid,
  p_traveler_id uuid,
  p_provider_id uuid,
  p_service_id uuid,
  p_service_title text,
  p_traveler_name text,
  p_check_in date,
  p_check_out date,
  p_guests integer,
  p_rooms integer,
  p_total_price numeric,
  p_contact_phone text,
  p_contact_email text,
  p_payment_method text,
  p_taxes numeric DEFAULT 0,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_travelers jsonb DEFAULT '[]'::jsonb
)
RETURNS uuid AS $$
DECLARE
  v_available int;
  v_category text;
  v_booking_id uuid;
  v_traveler record;
BEGIN
  IF (p_metadata->>'package_id' IS NOT NULL) THEN
    SELECT available_slots INTO v_available FROM public.booking_packages WHERE id = (p_metadata->>'package_id')::uuid FOR UPDATE;
    IF v_available < p_guests THEN RAISE EXCEPTION 'Not enough slots available in this package.'; END IF;
    UPDATE public.booking_packages SET available_slots = available_slots - p_guests WHERE id = (p_metadata->>'package_id')::uuid;
  ELSE
    SELECT available_slots, category INTO v_available, v_category FROM public.services WHERE id = p_service_id FOR UPDATE;
    IF NOT (v_category ILIKE '%apartment%' OR v_category ILIKE '%home%') THEN
      IF v_available < p_rooms THEN RAISE EXCEPTION 'Not enough rooms/slots available for this service.'; END IF;
      UPDATE public.services SET available_slots = available_slots - p_rooms WHERE id = p_service_id;
    END IF;
  END IF;

  INSERT INTO public.bookings (
    id, traveler_id, provider_id, service_id, service_title, traveler_name,
    status, check_in, check_out, guests, rooms, total_price, taxes,
    contact_phone, contact_email, payment_method, metadata
  ) VALUES (
    p_booking_id, p_traveler_id, p_provider_id, p_service_id, p_service_title, p_traveler_name,
    'pending', p_check_in, p_check_out, p_guests, p_rooms, p_total_price, p_taxes,
    p_contact_phone, p_contact_email, p_payment_method, p_metadata
  ) RETURNING id INTO v_booking_id;

  FOR v_traveler IN SELECT * FROM jsonb_to_recordset(p_travelers) AS x(name text, age int, gender text, passport text)
  LOOP
    INSERT INTO public.travelers (booking_id, name, age, gender, passport)
    VALUES (v_booking_id, v_traveler.name, v_traveler.age, v_traveler.gender, v_traveler.passport);
  END LOOP;

  INSERT INTO public.system_activities (title, subtitle, type, user_id, user_name, metadata)
  VALUES ('New Secure Booking', p_traveler_name || ' booked ' || p_service_title, 'booking', p_traveler_id, p_traveler_name, jsonb_build_object('booking_id', v_booking_id, 'service_id', p_service_id));

  RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Account Deletion Function
CREATE OR REPLACE FUNCTION public.delete_user_self(reason text DEFAULT NULL)
RETURNS void AS $$
DECLARE
  _user_id uuid := auth.uid();
  _user_name text;
BEGIN
  IF _user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT name INTO _user_name FROM public.users WHERE id = _user_id;
  INSERT INTO public.system_activities (title, subtitle, type, user_name, metadata)
  VALUES ('Account Deleted: ' || COALESCE(_user_name, 'Unknown'), COALESCE(_user_name, 'Unknown') || ' has deleted their account. Reason: ' || COALESCE(reason, 'Not specified'), 'userDeletion', _user_name, jsonb_build_object('deleted_user_id', _user_id, 'reason', reason, 'deletion_time', now()));
  DELETE FROM auth.users WHERE id = _user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- Passport Encryption Function
CREATE OR REPLACE FUNCTION public.encrypt_traveler_passport()
RETURNS trigger AS $$
BEGIN
  IF NEW.passport IS NOT NULL THEN
    NEW.encrypted_passport := pgp_sym_encrypt(NEW.passport, 'somsafar-secure-key-2026');
    NEW.passport := 'ENCRYPTED';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. TRIGGERS

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS tr_encrypt_passport ON public.travelers;
CREATE TRIGGER tr_encrypt_passport BEFORE INSERT OR UPDATE ON public.travelers FOR EACH ROW EXECUTE FUNCTION public.encrypt_traveler_passport();

-- 4. ENABLE RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.taxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.travelers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lookups ENABLE ROW LEVEL SECURITY;

-- 5. RLS POLICIES

-- USERS
CREATE POLICY "Users can view own and provider profiles" ON public.users FOR SELECT TO authenticated USING (auth.uid() = id OR role = 'provider' OR role = 'provider_helper' OR public.is_admin());
CREATE POLICY "Users can insert their own profile" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- SERVICES
CREATE POLICY "Anyone can view active services" ON public.services FOR SELECT USING (status = 'active');
CREATE POLICY "Providers can manage their own services" ON public.services FOR ALL USING (auth.uid() = provider_id OR public.is_admin());

-- BOOKINGS
CREATE POLICY "Travelers view own bookings" ON public.bookings FOR SELECT USING (auth.uid() = traveler_id);
CREATE POLICY "Travelers create bookings" ON public.bookings FOR INSERT WITH CHECK (auth.uid() = traveler_id);
CREATE POLICY "Providers view own bookings" ON public.bookings FOR SELECT USING (auth.uid() = provider_id OR provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid()) OR public.is_admin());
CREATE POLICY "Admin full access to all bookings" ON public.bookings FOR ALL TO authenticated USING (public.is_admin());

-- CHATS
CREATE POLICY "Users can view chats for their bookings" ON public.chats FOR SELECT USING (EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND (traveler_id = auth.uid() OR provider_id = auth.uid() OR provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid()) OR public.is_admin())));
CREATE POLICY "Users can send messages" ON public.chats FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- LOOKUPS
CREATE POLICY "Anyone can view lookups" ON public.lookups FOR SELECT USING (is_active = true);

-- 6. DATA SEEDING (LOOKUPS)
INSERT INTO public.lookups (category, key, label, icon) VALUES
('category', 'hotel', 'Hotel', 'hotel'),
('category', 'apartment', 'Apartment', 'apartment'),
('category', 'tour', 'Tour', 'tour'),
('region', 'banadir', 'Banaadir', 'map'),
('region', 'bari', 'Bari', 'map'),
('region', 'lower_juba', 'Jubbada Hoose', 'map'),
('amenity_hotel', 'wifi', 'WiFi', 'wifi'),
('amenity_hotel', 'pool', 'Pool', 'pool'),
('language', 'so', 'Somali', 'language'),
('language', 'en', 'English', 'language')
ON CONFLICT (category, key) DO NOTHING;

-- SYSTEM SETTINGS SEEDing
INSERT INTO public.system_settings (key, value, description)
VALUES ('maintenance_mode', '{"enabled": false}', 'Global kill-switch'),
       ('rate_limit_config', '{"requests_per_minute": 60}', 'Rate limiting')
ON CONFLICT (key) DO NOTHING;
