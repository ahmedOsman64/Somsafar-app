-- 1. Idempotency: Ensure a booking cannot have multiple successful transactions
-- We use a partial unique index to allow multiple failures but only one success.
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_success_per_booking 
ON public.payment_transactions (booking_id) 
WHERE (transaction_status = 'SUCCESSFUL');

-- Ensure reference_id and transaction_id are unique across the table
ALTER TABLE public.payment_transactions 
ADD CONSTRAINT unique_reference_id UNIQUE (reference_id);

-- Optional: If transaction_id is returned by WaafiPay, make it unique too.
-- Note: Some gateways might reuse transaction IDs in rare cases, but usually they are unique.
ALTER TABLE public.payment_transactions 
ADD CONSTRAINT unique_waafipay_transaction_id UNIQUE (waafipay_transaction_id); 
-- Note: Checking if column name is waafipay_transaction_id or similar.


-- 2. Audit Logs Enhancement: IP and User Agent tracking
-- Assuming table audit_logs exists, we ensure it has the right columns if not already there.
-- DO NOT fail if they exist.
ALTER TABLE IF EXISTS public.audit_logs 
ADD COLUMN IF NOT EXISTS ip_address TEXT,
ADD COLUMN IF NOT EXISTS device_info TEXT;

-- 3. Row Level Security (RLS)
-- Enable RLS on sensitive tables
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Policies for payment_transactions
DROP POLICY IF EXISTS "Users can view their own transactions" ON public.payment_transactions;
CREATE POLICY "Users can view their own transactions" 
ON public.payment_transactions FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all transactions" ON public.payment_transactions;
CREATE POLICY "Admins can view all transactions" 
ON public.payment_transactions FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policies for audit_logs (Restrictive)
DROP POLICY IF EXISTS "Users can view their own logs" ON public.audit_logs;
CREATE POLICY "Users can view their own logs" 
ON public.audit_logs FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all logs" ON public.audit_logs;
CREATE POLICY "Admins can view all logs" 
ON public.audit_logs FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 4. Payment Attempts Tracking (Fraud Detection)
CREATE TABLE IF NOT EXISTS public.payment_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  booking_id UUID,
  ip_address TEXT,
  attempted_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  status TEXT -- 'started', 'completed', 'failed'
);

ALTER TABLE public.payment_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view payment attempts" 
ON public.payment_attempts FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 5. Webhook Replay Protection
CREATE TABLE IF NOT EXISTS public.webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id TEXT UNIQUE NOT NULL,
  payload JSONB,
  processed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.webhook_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view webhook events" 
ON public.webhook_events FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 6. Rate Limiting Function (SQL)
-- This function checks if a user has exceeded payment attempts in the last minute.
CREATE OR REPLACE FUNCTION check_payment_rate_limit(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT count(*) INTO v_count 
  FROM public.payment_attempts 
  WHERE user_id = p_user_id 
    AND attempted_at > now() - interval '1 minute';
  
  RETURN v_count < 5; -- Limit to 5 attempts per minute
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Revoke execute from public to prevent anon access, grant to authenticated users only
REVOKE EXECUTE ON FUNCTION public.check_payment_rate_limit(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_payment_rate_limit(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_payment_rate_limit(UUID) TO service_role;


-- 7. Automated Audit Triggers for manual status changes
-- This ensures that even manual updates via the Supabase Dashboard are logged.
CREATE OR REPLACE FUNCTION public.fn_audit_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  IF (TG_TABLE_NAME = 'bookings') THEN
    IF (NEW.payment_status IS DISTINCT FROM OLD.payment_status OR NEW.status IS DISTINCT FROM OLD.status) THEN
      INSERT INTO public.audit_logs (user_id, action_performed, metadata)
      VALUES (
        v_user_id,
        'BOOKING_STATUS_UPDATE',
        jsonb_build_object(
          'table', TG_TABLE_NAME,
          'id', NEW.id,
          'old_payment_status', OLD.payment_status,
          'new_payment_status', NEW.payment_status,
          'old_booking_status', OLD.status,
          'new_booking_status', NEW.status,
          'trigger', 'auto_audit'
        )
      );
    END IF;
  ELSIF (TG_TABLE_NAME = 'payment_transactions') THEN
    IF (NEW.transaction_status IS DISTINCT FROM OLD.transaction_status) THEN
      INSERT INTO public.audit_logs (user_id, action_performed, metadata)
      VALUES (
        v_user_id,
        'TRANSACTION_STATUS_UPDATE',
        jsonb_build_object(
          'table', TG_TABLE_NAME,
          'id', NEW.id,
          'booking_id', NEW.booking_id,
          'old_status', OLD.transaction_status,
          'new_status', NEW.transaction_status,
          'trigger', 'auto_audit'
        )
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- Attach to bookings
DROP TRIGGER IF EXISTS trg_audit_bookings_status ON public.bookings;
CREATE TRIGGER trg_audit_bookings_status
AFTER UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_status_change();

-- Attach to payment_transactions
DROP TRIGGER IF EXISTS trg_audit_transactions_status ON public.payment_transactions;
CREATE TRIGGER trg_audit_transactions_status
AFTER UPDATE ON public.payment_transactions
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_status_change();

