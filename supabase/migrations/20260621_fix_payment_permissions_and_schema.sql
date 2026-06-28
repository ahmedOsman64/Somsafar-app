-- 20260621_fix_payment_permissions_and_schema.sql
-- 1. Add missing metadata column to payment_attempts
ALTER TABLE public.payment_attempts 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- 2. Add INSERT policies for authenticated users
-- These are needed if the client-side ever inserts directly, 
-- but also help if the Edge Function uses the user's JWT.

-- Payment Attempts
DROP POLICY IF EXISTS "Users can insert their own payment attempts" ON public.payment_attempts;
CREATE POLICY "Users can insert their own payment attempts" 
ON public.payment_attempts FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Payment Transactions
DROP POLICY IF EXISTS "Users can insert their own transactions" ON public.payment_transactions;
CREATE POLICY "Users can insert their own transactions" 
ON public.payment_transactions FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Audit Logs
DROP POLICY IF EXISTS "Users can insert their own audit logs" ON public.audit_logs;
CREATE POLICY "Users can insert their own audit logs" 
ON public.audit_logs FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- 3. Ensure users can update their own bookings status (needed if not using service role)
DROP POLICY IF EXISTS "Users can update their own bookings" ON public.bookings;
CREATE POLICY "Users can update their own bookings" 
ON public.bookings FOR UPDATE 
TO authenticated 
USING (auth.uid() = traveler_id)
WITH CHECK (auth.uid() = traveler_id);

-- 4. Grant necessary permissions to authenticated role
GRANT INSERT, UPDATE ON public.payment_attempts TO authenticated;
GRANT INSERT, UPDATE ON public.payment_transactions TO authenticated;
GRANT INSERT, UPDATE ON public.audit_logs TO authenticated;
GRANT UPDATE ON public.bookings TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
