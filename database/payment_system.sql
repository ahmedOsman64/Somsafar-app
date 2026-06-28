-- Somsafar Payment System Database Setup

-- 1. Payment Transactions Table
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    invoice_id text UNIQUE NOT NULL,
    reference_id text UNIQUE NOT NULL,
    amount numeric(10, 2) NOT NULL,
    payment_method text NOT NULL,
    transaction_status text DEFAULT 'PENDING' CHECK (transaction_status IN ('PENDING', 'SUCCESSFUL', 'FAILED', 'CANCELLED')),
    waafipay_response jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

-- 2. Audit Logs Table (Detailed for payments)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    action_performed text NOT NULL,
    ip_address text,
    device_info text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 3. Payment Rate Limiting Table
CREATE TABLE IF NOT EXISTS public.payment_attempts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    ip_address text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Index for rate limit checking
CREATE INDEX IF NOT EXISTS idx_payment_attempts_user_time ON public.payment_attempts (user_id, created_at);

-- 4. RLS Policies

-- Payment Transactions: Users can view their own
DROP POLICY IF EXISTS "Users can view own transactions" ON public.payment_transactions;
CREATE POLICY "Users can view own transactions" ON public.payment_transactions
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- Payment Transactions: Admins can view all
DROP POLICY IF EXISTS "Admins can view all transactions" ON public.payment_transactions;
CREATE POLICY "Admins can view all transactions" ON public.payment_transactions
    FOR SELECT TO authenticated
    USING (public.is_admin());

-- Audit Logs: Users can view their own
DROP POLICY IF EXISTS "Users can view own audit logs" ON public.audit_logs;
CREATE POLICY "Users can view own audit logs" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- Audit Logs: Admins can view all
DROP POLICY IF EXISTS "Admins can view all audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view all audit logs" ON public.audit_logs
    FOR ALL TO authenticated
    USING (public.is_admin());

-- System (Edge Functions) can insert records
DROP POLICY IF EXISTS "Service role can do everything" ON public.payment_transactions;
CREATE POLICY "Service role can do everything" ON public.payment_transactions 
    FOR ALL TO service_role USING (true);

DROP POLICY IF EXISTS "Service role can insert audit logs" ON public.audit_logs;
CREATE POLICY "Service role can insert audit logs" ON public.audit_logs 
    FOR ALL TO service_role USING (true);

DROP POLICY IF EXISTS "Service role can manage attempts" ON public.payment_attempts;
CREATE POLICY "Service role can manage attempts" ON public.payment_attempts 
    FOR ALL TO service_role USING (true);

-- 5. Rate Limiting Function
CREATE OR REPLACE FUNCTION public.check_payment_rate_limit(p_user_id uuid)
RETURNS boolean AS $$
DECLARE
    attempt_count integer;
BEGIN
    SELECT count(*) INTO attempt_count
    FROM public.payment_attempts
    WHERE user_id = p_user_id
    AND created_at > now() - interval '1 minute';
    
    RETURN attempt_count < 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Security Hardening: Revoke execute from public/anon, grant to authenticated
REVOKE EXECUTE ON FUNCTION public.check_payment_rate_limit(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_payment_rate_limit(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_payment_rate_limit(uuid) TO service_role;

