-- Migration: Add linked_service_id and discount_percent to special_offers
-- Run this in Supabase SQL Editor

ALTER TABLE special_offers
  ADD COLUMN IF NOT EXISTS linked_service_id UUID REFERENCES services(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS discount_percent  NUMERIC(5,2);

-- Optional: index for fast lookups when applying offer during booking
CREATE INDEX IF NOT EXISTS idx_special_offers_linked_service
  ON special_offers (linked_service_id)
  WHERE linked_service_id IS NOT NULL AND active = TRUE;
