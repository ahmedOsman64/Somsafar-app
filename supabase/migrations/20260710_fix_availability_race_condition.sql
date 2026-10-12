-- 1. Update check_service_availability with explicit search_path
CREATE OR REPLACE FUNCTION public.check_service_availability(
  p_service_id uuid,
  p_check_in date,
  p_check_out date
)
RETURNS integer
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_capacity integer;
  v_occupied integer;
BEGIN
  -- Get service total capacity
  SELECT COALESCE((metadata->>'rooms')::integer, available_slots, 1)
  INTO v_total_capacity
  FROM public.services
  WHERE id = p_service_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- Count occupied slots/rooms for overlapping dates
  SELECT COALESCE(SUM(rooms), 0)
  INTO v_occupied
  FROM public.bookings
  WHERE service_id = p_service_id
    AND status IN ('pending', 'confirmed')
    AND check_in < p_check_out
    AND check_out > p_check_in;

  RETURN GREATEST(0, v_total_capacity - v_occupied);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.check_service_availability(uuid, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_service_availability(uuid, date, date) TO service_role;

-- 2. Create Atomic Reservation Function to Eliminate Overbooking Race Conditions
-- Locks the service row (FOR UPDATE) so concurrent requests wait their turn.
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
  p_service_id uuid,
  p_traveler_id uuid,
  p_check_in date,
  p_check_out date,
  p_rooms integer DEFAULT 1,
  p_total_price numeric DEFAULT 0,
  p_service_title text DEFAULT ''
)
RETURNS uuid
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_capacity integer;
  v_occupied integer;
  v_available integer;
  v_new_booking_id uuid;
BEGIN
  -- Row-level lock on target service row to prevent race conditions during concurrent bookings
  SELECT COALESCE((metadata->>'rooms')::integer, available_slots, 1)
  INTO v_total_capacity
  FROM public.services
  WHERE id = p_service_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Service with ID % not found', p_service_id;
  END IF;

  -- Calculate current active bookings for overlapping period
  SELECT COALESCE(SUM(rooms), 0)
  INTO v_occupied
  FROM public.bookings
  WHERE service_id = p_service_id
    AND status IN ('pending', 'confirmed')
    AND check_in < p_check_out
    AND check_out > p_check_in;

  v_available := v_total_capacity - v_occupied;

  IF v_available < p_rooms THEN
    RAISE EXCEPTION 'Insufficient availability: requested %, available %', p_rooms, v_available;
  END IF;

  -- Insert booking atomically
  INSERT INTO public.bookings (
    service_id,
    traveler_id,
    check_in,
    check_out,
    rooms,
    total_price,
    service_title,
    status,
    payment_status
  ) VALUES (
    p_service_id,
    p_traveler_id,
    p_check_in,
    p_check_out,
    p_rooms,
    p_total_price,
    p_service_title,
    'pending',
    'pending'
  )
  RETURNING id INTO v_new_booking_id;

  RETURN v_new_booking_id;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.create_booking_atomic(uuid, uuid, date, date, integer, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_booking_atomic(uuid, uuid, date, date, integer, numeric, text) TO service_role;
