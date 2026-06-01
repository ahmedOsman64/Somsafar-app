-- Somsafar Apartment Slot Reset Script
-- This script resets available_slots for all apartments and homes to 1
-- ensuring they are bookable regardless of previous strict slot decrements.
-- Atomic date-aware checking is handled by the application layer.

UPDATE public.services 
SET available_slots = 1 
WHERE category ILIKE '%apartment%' OR category ILIKE '%home%';

-- Optional: Verify the change
SELECT id, title, category, available_slots 
FROM public.services 
WHERE category ILIKE '%apartment%' OR category ILIKE '%home%';
