-- SomSafar Bulletproof System Hardening
-- 0. Ensure Required Tables Exist

-- Create Travelers Table if not exists
CREATE TABLE IF NOT EXISTS public.travelers (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid NOT NULL, -- Reference added later if needed
  name text NOT NULL,
  age integer NOT NULL,
  gender text NOT NULL,
  passport text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Create Booking Packages Table if not exists
CREATE TABLE IF NOT EXISTS public.booking_packages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  provider_id uuid NOT NULL,
  type text NOT NULL,
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

-- 1. Concurrency Control (Phase 1)

-- Add available_slots to services if not exists
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='services' AND column_name='available_slots') THEN
    ALTER TABLE public.services ADD COLUMN available_slots integer DEFAULT 1;
  END IF;
END $$;

-- Ensure booking_packages has a clear slot tracking
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='booking_packages' AND column_name='available_slots') THEN
    ALTER TABLE public.booking_packages ADD COLUMN available_slots integer;
  END IF;
  
  -- Initialize available_slots if NULL
  UPDATE public.booking_packages 
  SET available_slots = max_people 
  WHERE available_slots IS NULL;
END $$;

-- Safe Booking RPC Function
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
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_travelers jsonb DEFAULT '[]'::jsonb
)
RETURNS uuid AS $$
DECLARE
  v_available int;
  v_booking_id uuid;
  v_traveler record;
BEGIN
  -- 1. Lock the service/package row for update
  -- Check if it's a service or a package booking
  IF (p_metadata->>'package_id' IS NOT NULL) THEN
    SELECT available_slots INTO v_available 
    FROM public.booking_packages 
    WHERE id = (p_metadata->>'package_id')::uuid 
    FOR UPDATE;
    
    IF v_available < p_guests THEN
      RAISE EXCEPTION 'Not enough slots available in this package.';
    END IF;

    -- Update slots
    UPDATE public.booking_packages 
    SET available_slots = available_slots - p_guests 
    WHERE id = (p_metadata->>'package_id')::uuid;
  ELSE
    SELECT available_slots INTO v_available 
    FROM public.services 
    WHERE id = p_service_id 
    FOR UPDATE;

    IF v_available < p_rooms THEN
      RAISE EXCEPTION 'Not enough rooms/slots available for this service.';
    END IF;

    -- Update slots
    UPDATE public.services 
    SET available_slots = available_slots - p_rooms 
    WHERE id = p_service_id;
  END IF;

  -- 2. Insert the booking
  INSERT INTO public.bookings (
    id, traveler_id, provider_id, service_id, service_title, traveler_name,
    status, check_in, check_out, guests, rooms, total_price,
    contact_phone, contact_email, payment_method, metadata
  ) VALUES (
    p_booking_id, p_traveler_id, p_provider_id, p_service_id, p_service_title, p_traveler_name,
    'pending', p_check_in, p_check_out, p_guests, p_rooms, p_total_price,
    p_contact_phone, p_contact_email, p_payment_method, p_metadata
  ) RETURNING id INTO v_booking_id;

  -- 3. Insert travelers if any
  FOR v_traveler IN SELECT * FROM jsonb_to_recordset(p_travelers) AS x(name text, age int, gender text, passport text)
  LOOP
    INSERT INTO public.travelers (booking_id, name, age, gender, passport)
    VALUES (v_booking_id, v_traveler.name, v_traveler.age, v_traveler.gender, v_traveler.passport);
  END LOOP;

  -- 4. Log the activity
  INSERT INTO public.system_activities (title, subtitle, type, user_id, user_name, metadata)
  VALUES (
    'New Secure Booking',
    p_traveler_name || ' booked ' || p_service_title,
    'booking',
    p_traveler_id,
    p_traveler_name,
    jsonb_build_object('booking_id', v_booking_id, 'service_id', p_service_id)
  );

  RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Data Security (Phase 2)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt sensitive data in travelers table
-- We'll add a secret_key column to a secure schema for true isolation, 
-- but for this demo, we'll use a server-side pepper.

-- Add encrypted_passport column if not exists
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='travelers' AND column_name='encrypted_passport') THEN
    ALTER TABLE public.travelers ADD COLUMN encrypted_passport bytea;
  END IF;
END $$;

-- Function to encrypt passport
CREATE OR REPLACE FUNCTION public.encrypt_traveler_passport()
RETURNS trigger AS $$
BEGIN
  IF NEW.passport IS NOT NULL THEN
    -- Use a dedicated key (in production, use Supabase Vault or a GUC)
    NEW.encrypted_passport := pgp_sym_encrypt(NEW.passport, 'somsafar-secure-key-2026');
    NEW.passport := 'ENCRYPTED'; -- Mask the plain text
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_encrypt_passport ON public.travelers;
CREATE TRIGGER tr_encrypt_passport
BEFORE INSERT OR UPDATE ON public.travelers
FOR EACH ROW EXECUTE FUNCTION public.encrypt_traveler_passport();

-- Function to decrypt passport (Restricted to Admins and the Provider of the booking)
CREATE OR REPLACE FUNCTION public.get_decrypted_passport(p_traveler_id uuid)
RETURNS text AS $$
DECLARE
  v_encrypted bytea;
  v_booking_id uuid;
  v_provider_id uuid;
BEGIN
  SELECT encrypted_passport, booking_id INTO v_encrypted, v_booking_id 
  FROM public.travelers WHERE id = p_traveler_id;
  
  SELECT provider_id INTO v_provider_id FROM public.bookings WHERE id = v_booking_id;

  -- Security Check: Admin or Provider only
  IF (public.is_admin() OR auth.uid() = v_provider_id) THEN
    RETURN pgp_sym_decrypt(v_encrypted, 'somsafar-secure-key-2026');
  ELSE
    RAISE EXCEPTION 'Unauthorized to view sensitive data.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Governance & Kill-switch (Phase 3)
CREATE TABLE IF NOT EXISTS public.system_settings (
  key text PRIMARY KEY,
  value jsonb,
  description text,
  updated_at timestamp with time zone DEFAULT now()
);

INSERT INTO public.system_settings (key, value, description)
VALUES 
('maintenance_mode', '{"enabled": false, "message": "System is under maintenance."}', 'Global kill-switch for bookings'),
('rate_limit_config', '{"requests_per_minute": 60}', 'API rate limiting configuration')
ON CONFLICT (key) DO NOTHING;

-- User Data Encryption (Phone numbers)
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='encrypted_phone') THEN
    ALTER TABLE public.users ADD COLUMN encrypted_phone bytea;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.encrypt_user_phone()
RETURNS trigger AS $$
BEGIN
  IF NEW.phone IS NOT NULL AND NEW.phone != 'ENCRYPTED' THEN
    NEW.encrypted_phone := pgp_sym_encrypt(NEW.phone, 'somsafar-secure-key-2026');
    NEW.phone := 'ENCRYPTED';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_encrypt_phone ON public.users;
CREATE TRIGGER tr_encrypt_phone
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.encrypt_user_phone();

-- API Rate Limiting (Simple Table-based)
CREATE TABLE IF NOT EXISTS public.request_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  ip_address text,
  endpoint text,
  created_at timestamp with time zone DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.check_rate_limit()
RETURNS boolean AS $$
DECLARE
  v_count int;
  v_limit int;
BEGIN
  SELECT (value->>'requests_per_minute')::int INTO v_limit 
  FROM public.system_settings WHERE key = 'rate_limit_config';
  
  SELECT count(*) INTO v_count 
  FROM public.request_logs 
  WHERE (user_id = auth.uid() OR ip_address = inet_client_addr()::text)
  AND created_at > now() - interval '1 minute';

  IF v_count >= v_limit THEN
    RETURN false;
  END IF;

  INSERT INTO public.request_logs (user_id, ip_address, endpoint)
  VALUES (auth.uid(), inet_client_addr()::text, TG_NAME);
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Audit Triggers
CREATE OR REPLACE FUNCTION public.audit_log_deletions()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.system_activities (title, subtitle, type, user_id, user_name, metadata)
  VALUES (
    'Record Deleted from ' || TG_TABLE_NAME,
    'A record with ID ' || OLD.id || ' was removed.',
    'deletion',
    auth.uid(),
    (SELECT name FROM public.users WHERE id = auth.uid()),
    jsonb_build_object('table', TG_TABLE_NAME, 'old_data', to_jsonb(OLD))
  );
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_audit_bookings_delete ON public.bookings;
CREATE TRIGGER tr_audit_bookings_delete
AFTER DELETE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.audit_log_deletions();

DROP TRIGGER IF EXISTS tr_audit_payments_delete ON public.payments;
CREATE TRIGGER tr_audit_payments_delete
AFTER DELETE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.audit_log_deletions();
