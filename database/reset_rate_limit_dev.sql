-- Reset payment attempts to clear the current 429 rate limit block
-- Run this in the Supabase Dashboard SQL editor to unblock testing

DELETE FROM public.payment_attempts;

-- Also bump rate limit from 5 to 10 attempts per minute during development
CREATE OR REPLACE FUNCTION check_payment_rate_limit(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT count(*) INTO v_count 
  FROM public.payment_attempts 
  WHERE user_id = p_user_id 
    AND attempted_at > now() - interval '1 minute';
  
  RETURN v_count < 10; -- Allow 10 attempts per minute (was 5)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
