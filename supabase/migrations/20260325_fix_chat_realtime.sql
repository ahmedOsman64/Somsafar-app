-- 1. Enable Realtime for 'chats' table
BEGIN;
  -- Add chats to the supabase_realtime publication
  ALTER PUBLICATION supabase_realtime ADD TABLE chats;
COMMIT;

-- 2. Ensure RLS is enabled for 'chats'
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;

-- 3. Create/Update RLS Policies for 'chats'

-- Policy: Users can see messages for bookings they are involved in
DROP POLICY IF EXISTS "Users can see messages for their bookings" ON chats;
CREATE POLICY "Users can see messages for their bookings" ON chats
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM bookings
    WHERE bookings.id = chats.booking_id
    AND (
      -- Admin sees everything
      (SELECT role FROM users WHERE id = auth.uid()::text) = 'admin' OR
      -- Provider/Helper sees everything for their booking
      bookings.provider_id = (SELECT provider_id FROM users WHERE id = auth.uid()::text) OR
      -- Traveler sees only non-internal notes OR their own messages
      (
        bookings.traveler_id = auth.uid()::text AND
        (chats.is_internal_note = false OR chats.sender_id = auth.uid()::text)
      )
    )
  )
);

-- Policy: Users can insert messages for bookings they are involved in
DROP POLICY IF EXISTS "Users can insert messages for their bookings" ON chats;
CREATE POLICY "Users can insert messages for their bookings" ON chats
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM bookings
    WHERE bookings.id = chats.booking_id
    AND (
      bookings.traveler_id = auth.uid()::text OR
      bookings.provider_id = (SELECT provider_id FROM users WHERE id = auth.uid()::text) OR
      (SELECT role FROM users WHERE id = auth.uid()::text) = 'admin'
    )
  )
);
