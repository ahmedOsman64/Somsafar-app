-- Create a function to automatically confirm paid bookings that have been pending for more than 1 hour
CREATE OR REPLACE FUNCTION public.auto_confirm_pending_bookings()
RETURNS void
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.bookings
  SET status = 'confirmed'
  WHERE status = 'pending'
    AND payment_status = 'paid'
    AND created_at < NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.auto_confirm_pending_bookings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_confirm_pending_bookings() TO service_role;

-- Schedule the function to run every 5 minutes using pg_cron
DO $$
BEGIN
  -- Enable pg_cron extension
  CREATE EXTENSION IF NOT EXISTS pg_cron;

  -- Unschedules the job if it already exists to avoid duplication
  BEGIN
    PERFORM cron.unschedule('auto-confirm-bookings-job');
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- Schedule the job
  PERFORM cron.schedule(
    'auto-confirm-bookings-job',
    '*/5 * * * *', -- Every 5 minutes
    'SELECT public.auto_confirm_pending_bookings();'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron extension is not available or could not be configured. Auto-confirm background task will not run automatically.';
END $$;
