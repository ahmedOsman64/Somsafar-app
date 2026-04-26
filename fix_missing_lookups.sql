-- Add missing service categories to lookups
INSERT INTO public.lookups (category, key, label, icon) VALUES
('category', 'hotel', 'Hotel', 'hotel'),
('category', 'apartment', 'Apartment', 'apartment'),
('category', 'tour', 'Tour', 'tour')
ON CONFLICT (category, key) DO NOTHING;
