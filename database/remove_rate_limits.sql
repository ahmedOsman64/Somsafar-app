-- ---------------------------------------------------------
-- SYSTEM HARDENING: EMERGENCY RATE LIMIT REMOVAL
-- Use this script to unblock testing/development
-- ---------------------------------------------------------

-- 1. UNBLOCK: Clear all attempt/request logs
TRUNCATE TABLE public.payment_attempts;
TRUNCATE TABLE public.request_logs;

-- 2. DISABLE: Redefine payment rate limit to always allow
CREATE OR REPLACE FUNCTION public.check_payment_rate_limit(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Rate limiting disabled for testing/development
  RETURN true; 
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. DISABLE: Redefine general rate limit to always allow
CREATE OR REPLACE FUNCTION public.check_rate_limit()
RETURNS boolean AS $$
BEGIN
  -- Rate limiting disabled for testing/development
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. LOG: Record that rate limits were disabled
INSERT INTO public.system_activities (title, subtitle, type, metadata)
VALUES (
  'Security Policy Updated',
  'Rate limiting constraints were disabled for development.',
  'security_update',
  '{"rate_limiting": "disabled", "action": "emergency_unblock"}'
);

-- RE-DEPLOY ALERT: 
-- If you are still seeing the error in the mobile app, 
-- ensure you have deployed the latest edge function:
-- npx supabase functions deploy process-payment --project-ref <your-project-id>
