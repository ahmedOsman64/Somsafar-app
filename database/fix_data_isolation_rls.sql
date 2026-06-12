-- Data Isolation Fix: Strictly enforce RLS policies for all user-specific data.

-- 1. USERS: Standard users should only see themselves and 'provider' profiles.
-- Providers and Admin have broader visibility, but regular customers should not see each other.
DROP POLICY IF EXISTS "Users can view own and provider profiles" ON public.users;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.users;
CREATE POLICY "Users can view own and provider profiles" ON public.users
FOR SELECT TO authenticated
USING (
  auth.uid() = id 
  OR role = 'provider' 
  OR role = 'provider_helper'
  OR public.is_admin()
);

-- 2. BOOKINGS: Only the traveler who booked or the provider of the service can see the booking.
DROP POLICY IF EXISTS "Travelers view own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Providers view bookings for their services" ON public.bookings;
DROP POLICY IF EXISTS "Helpers view provider bookings" ON public.bookings;

CREATE POLICY "Travelers view own bookings" ON public.bookings 
FOR SELECT USING (auth.uid() = traveler_id);

CREATE POLICY "Providers view own bookings" ON public.bookings 
FOR SELECT USING (auth.uid() = provider_id);

CREATE POLICY "Helpers view own bookings" ON public.bookings 
FOR SELECT USING (
  provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid()) OR public.is_admin()
);

-- 3. PAYMENTS: Strictly limit to the buyer or the seller.
DROP POLICY IF EXISTS "Travelers view payments for their bookings" ON public.payments;
DROP POLICY IF EXISTS "Providers view payments for their bookings" ON public.payments;
DROP POLICY IF EXISTS "Helpers view provider payments" ON public.payments;

CREATE POLICY "Travelers view own payments" ON public.payments 
FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND traveler_id = auth.uid())
);

CREATE POLICY "Providers view own payments" ON public.payments 
FOR SELECT USING (
  auth.uid()::text = provider_id OR
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND provider_id = auth.uid())
);

CREATE POLICY "Helpers view own payments" ON public.payments 
FOR SELECT USING (
  provider_id = (SELECT provider_id FROM public.users WHERE id = auth.uid()) OR
  EXISTS (SELECT 1 FROM public.bookings WHERE id = booking_id AND provider_id::text = (SELECT provider_id FROM public.users WHERE id = auth.uid())) OR
  public.is_admin()
);

-- 4. CHATS: Strictly limit to those involved in the booking.
DROP POLICY IF EXISTS "Travelers view visible chats for their bookings" ON public.chats;
DROP POLICY IF EXISTS "Providers view all chats for their bookings" ON public.chats;

CREATE POLICY "Travelers view own chats" ON public.chats 
FOR SELECT USING (
  visible_to_traveler = true AND EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id AND traveler_id = auth.uid()
  )
);

CREATE POLICY "Providers view own chats" ON public.chats 
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE id = booking_id AND provider_id = auth.uid()
  )
);

-- 5. NOTIFICATIONS: Only the user themselves.
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications 
FOR SELECT USING (auth.uid() = user_id);

-- 6. SUPPORT TICKETS: Only the creator.
DROP POLICY IF EXISTS "Users view own tickets" ON public.support_tickets;
CREATE POLICY "Users view own tickets" ON public.support_tickets 
FOR SELECT USING (auth.uid() = user_id);

-- 7. Ensure RLS is actually ENABLED for all these tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Safety: Admin always has full access (already in schema but reinforced here)
DROP POLICY IF EXISTS "Admin full access to all" ON public.bookings;
CREATE POLICY "Admin full access to all" ON public.bookings FOR ALL TO authenticated USING (public.is_admin());
