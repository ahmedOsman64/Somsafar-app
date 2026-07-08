-- Create a SECURITY DEFINER function to check service room/slot availability bypassing RLS.
-- This prevents overbooking and resolves client-side RLS data visibility limits.

CREATE OR REPLACE FUNCTION public.check_service_availability(
  p_service_id uuid,
  p_check_in date,
  p_check_out date
)
RETURNS integer
SECURITY DEFINER
AS $$
DECLARE
  v_category text;
  v_total_capacity integer;
  v_occupied integer;
BEGIN
  -- Get service category and total capacity
  SELECT category, 
         COALESCE((metadata->>'rooms')::integer, available_slots, 1)
  INTO v_category, v_total_capacity
  FROM public.services
  WHERE id = p_service_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- Count occupied slots/rooms for the given date range
  -- Overlap condition: bookingCheckIn < requestedCheckOut AND bookingCheckOut > requestedCheckIn
  SELECT COALESCE(SUM(rooms), 0)
  INTO v_occupied
  FROM public.bookings
  WHERE service_id = p_service_id
    AND status IN ('pending', 'confirmed') -- Only count active/pending bookings
    AND check_in < p_check_out
    AND check_out > p_check_in;

  RETURN GREATEST(0, v_total_capacity - v_occupied);
END;
$$ LANGUAGE plpgsql;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.check_service_availability(uuid, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_service_availability(uuid, date, date) TO service_role;
