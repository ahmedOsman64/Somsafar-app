-- Dynamic Tourism Booking System Update

-- 1. Create Travelers Table
CREATE TABLE IF NOT EXISTS public.travelers (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  age integer NOT NULL,
  gender text NOT NULL,
  passport text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. Create Booking Packages Table (Providers' Offers)
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
  images text[] DEFAULT '{}'::text[],
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 3. Create Booking Details Table (Package-specific fields)
CREATE TABLE IF NOT EXISTS public.booking_details (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE NOT NULL,
  key text NOT NULL,
  value text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 4. Update Bookings Table
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='package_type') THEN
    ALTER TABLE public.bookings ADD COLUMN package_type text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bookings' AND column_name='package_id') THEN
    ALTER TABLE public.bookings ADD COLUMN package_id uuid;
  END IF;
END $$;

-- 5. RLS POLICIES

-- Travelers
ALTER TABLE public.travelers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view travelers for their bookings" ON public.travelers;
CREATE POLICY "Users can view travelers for their bookings" ON public.travelers FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND (traveler_id = auth.uid() OR provider_id = auth.uid()))
);
DROP POLICY IF EXISTS "Travelers can insert travelers for their bookings" ON public.travelers;
CREATE POLICY "Travelers can insert travelers for their bookings" ON public.travelers FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND traveler_id = auth.uid())
);

-- Booking Packages
ALTER TABLE public.booking_packages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view active booking packages" ON public.booking_packages;
CREATE POLICY "Anyone can view active booking packages" ON public.booking_packages FOR SELECT USING (is_active = true);
DROP POLICY IF EXISTS "Providers can manage their own packages" ON public.booking_packages;
CREATE POLICY "Providers can manage their own packages" ON public.booking_packages FOR ALL USING (auth.uid() = provider_id);

-- Booking Details
ALTER TABLE public.booking_details ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view details for their bookings" ON public.booking_details;
CREATE POLICY "Users can view details for their bookings" ON public.booking_details FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND (traveler_id = auth.uid() OR provider_id = auth.uid()))
);
DROP POLICY IF EXISTS "Travelers can insert details for their bookings" ON public.booking_details;
CREATE POLICY "Travelers can insert details for their bookings" ON public.booking_details FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND traveler_id = auth.uid())
);
