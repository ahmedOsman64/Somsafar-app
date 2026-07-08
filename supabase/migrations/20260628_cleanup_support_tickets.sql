-- Create trigger to automatically delete support tickets older than 72 hours
CREATE OR REPLACE FUNCTION public.clean_expired_support_tickets()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM public.support_tickets 
  WHERE created_at < NOW() - INTERVAL '72 hours';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_clean_expired_support_tickets ON public.support_tickets;

CREATE TRIGGER tr_clean_expired_support_tickets
AFTER INSERT ON public.support_tickets
FOR EACH STATEMENT
EXECUTE FUNCTION public.clean_expired_support_tickets();
