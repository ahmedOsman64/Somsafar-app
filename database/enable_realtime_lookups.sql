-- Enable Realtime for all tables that use .stream() in the Flutter app
-- Run this SQL in the Supabase SQL Editor (supabase.com → SQL Editor)
-- This version checks if the table is already added to prevent the 42710 error.

DO $$
DECLARE
    table_names text[] := ARRAY[
        'lookups', 'services', 'users', 'taxes', 'system_activity', 
        'support_tickets', 'special_offers', 'reviews', 'notifications', 
        'highlights', 'financials', 'discounts', 'chats', 'bookings', 'banners'
    ];
    t text;
BEGIN
    FOREACH t IN ARRAY table_names
    LOOP
        IF EXISTS (
            SELECT 1 FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relname = t
        ) AND NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND schemaname = 'public' 
            AND tablename = t
        ) THEN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
            RAISE NOTICE 'Added table % to supabase_realtime publication', t;
        ELSE
            RAISE NOTICE 'Table % already exists in publication or does not exist in schema', t;
        END IF;
    END LOOP;
END $$;
