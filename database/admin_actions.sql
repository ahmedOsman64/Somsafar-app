-- =======================================================
-- ADMIN ACTION: DELETE USER
-- Run this script in the Supabase SQL Editor
-- =======================================================

CREATE OR REPLACE FUNCTION public.admin_delete_user(target_user_id uuid)
RETURNS void AS $$
DECLARE
  _user_name text;
  _admin_id uuid := auth.uid();
  _admin_name text;
  _admin_role text;
BEGIN
  -- 1. Check if caller is admin (requires looking at JWT metadata)
  _admin_role := (auth.jwt() -> 'user_metadata' ->> 'role');
  IF _admin_role != 'admin' THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can delete users';
  END IF;

  -- 2. Get details for the user being deleted
  SELECT name INTO _user_name FROM public.users WHERE id = target_user_id;
  
  -- 3. Get the admin's name
  SELECT name INTO _admin_name FROM public.users WHERE id = _admin_id;
  
  -- 4. Log the deletion to system activities
  INSERT INTO public.system_activities (title, subtitle, type, user_id, user_name, metadata)
  VALUES (
    'User Deleted by Admin: ' || COALESCE(_user_name, 'Unknown'),
    'Admin ' || COALESCE(_admin_name, 'Unknown') || ' deleted the user ' || COALESCE(_user_name, 'Unknown'),
    'userDeletion',
    _admin_id,
    _admin_name,
    jsonb_build_object('deleted_user_id', target_user_id)
  );

  -- 5. Delete the user from auth.users (This will cascade and delete public.users too)
  DELETE FROM auth.users WHERE id = target_user_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;
