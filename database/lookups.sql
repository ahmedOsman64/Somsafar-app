-- Lookups Table for Dynamic Form Options
CREATE TABLE IF NOT EXISTS public.lookups (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  category text NOT NULL, -- 'region', 'amenity', 'language', 'service'
  key text NOT NULL,
  label text NOT NULL,
  icon text, -- Optional icon identifier
  metadata jsonb DEFAULT '{}'::jsonb,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  UNIQUE(category, key)
);

-- Seed Data
INSERT INTO public.lookups (category, key, label, icon) VALUES
-- Categories
('category', 'hotel', 'Hotel', 'hotel'),
('category', 'apartment', 'Apartment', 'apartment'),
('category', 'tour', 'Tour', 'tour'),

-- Regions
('region', 'banadir', 'Banaadir', 'map'),
('region', 'bari', 'Bari', 'map'),
('region', 'gedo', 'Gedo', 'map'),
('region', 'mudug', 'Mudug', 'map'),
('region', 'nugaal', 'Nugaal', 'map'),
('region', 'hiran', 'Hiiraan', 'map'),
('region', 'bay', 'Bay', 'map'),
('region', 'bakol', 'Bakool', 'map'),
('region', 'lower_juba', 'Jubbada Hoose', 'map'),
('region', 'middle_juba', 'Jubbada Dhexe', 'map'),
('region', 'lower_shabelle', 'Shabeellaha Hoose', 'map'),
('region', 'middle_shabelle', 'Shabeellaha Dhexe', 'map'),
('region', 'galguduud', 'Galguduud', 'map'),
('region', 'awdal', 'Awdal', 'map'),
('region', 'togdheer', 'Togdheer', 'map'),
('region', 'sool', 'Sool', 'map'),
('region', 'sanaag', 'Sanaag', 'map'),
('region', 'woqooyi_galbeed', 'Woqooyi Galbeed', 'map'),

-- Amenities (Hotel)
('amenity_hotel', 'wifi', 'WiFi', 'wifi'),
('amenity_hotel', 'breakfast', 'Breakfast', 'restaurant'),
('amenity_hotel', 'pool', 'Pool', 'pool'),
('amenity_hotel', 'parking', 'Parking', 'local_parking'),
('amenity_hotel', 'gym', 'Gym', 'fitness_center'),
('amenity_hotel', 'spa', 'Spa', 'spa'),
('amenity_hotel', 'ac', 'AC', 'ac_unit'),

-- Amenities (Apartment)
('amenity_apt', 'kitchen', 'Kitchen', 'kitchen'),
('amenity_apt', 'washing_machine', 'Washing Machine', 'local_laundry_service'),
('amenity_apt', 'balcony', 'Balcony', 'balcony'),
('amenity_apt', 'tv', 'TV', 'tv'),
('amenity_apt', 'ac', 'Air Conditioning', 'ac_unit'),
('amenity_apt', 'wifi', 'WiFi', 'wifi'),
('amenity_apt', 'parking', 'Parking', 'local_parking'),
('amenity_apt', 'pool', 'Swimming Pool', 'pool'),
('amenity_apt', 'gym', 'Gym / Fitness', 'fitness_center'),
('amenity_apt', 'heating', 'Heating', 'hvac'),
('amenity_apt', 'security', '24/7 Security', 'security'),

-- Languages
('language', 'en', 'English', 'language'),
('language', 'so', 'Somali', 'language'),
('language', 'ar', 'Arabic', 'language'),
('language', 'it', 'Italian', 'language'),

-- Preferred Services (Custom Tour)
('service', 'guide', 'Guide', 'person'),
('service', 'transport', 'Private Transport', 'directions_car'),
('service', 'photographer', 'Photographer', 'camera_alt'),
('service', 'vip', 'VIP Access', 'star'),
('service', 'translator', 'Translator', 'translate');

-- RLS
ALTER TABLE public.lookups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view lookups" ON public.lookups FOR SELECT USING (is_active = true);
