-- Run this in your Supabase SQL Editor to add the new apartment amenities

INSERT INTO public.lookups (category, key, label, icon) VALUES
('amenity_apt', 'ac', 'Air Conditioning', 'ac_unit'),
('amenity_apt', 'wifi', 'WiFi', 'wifi'),
('amenity_apt', 'parking', 'Parking', 'local_parking'),
('amenity_apt', 'pool', 'Swimming Pool', 'pool'),
('amenity_apt', 'gym', 'Gym / Fitness', 'fitness_center'),
('amenity_apt', 'heating', 'Heating', 'hvac'),
('amenity_apt', 'security', '24/7 Security', 'security')
ON CONFLICT (category, key) DO UPDATE 
SET label = EXCLUDED.label, icon = EXCLUDED.icon;
