-- FIX: RLS Violation on Service deactivation
-- This script fixes the "new row violates row-level security policy" error (42501)
-- by explicitly defining UPDATE policies with WITH CHECK clauses.

-- 1. Drop existing update policies for services to start fresh
DROP POLICY IF EXISTS "Providers can update their own services" ON public.services;
DROP POLICY IF EXISTS "Helpers can manage provider services" ON public.services;
DROP POLICY IF EXISTS "Admin has full access to services" ON public.services;

-- 2. CREATE: Admin Policy (Full Access)
CREATE POLICY "Admin has full access to services" ON public.services 
FOR ALL TO authenticated 
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  -- Fallback to a direct field check in public.users if metadata is missing
  OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- 3. CREATE: Provider Policy (Own services)
-- We use USING for SELECT/DELETE and WITH CHECK for INSERT/UPDATE
CREATE POLICY "Providers can manage own services" ON public.services 
FOR ALL TO authenticated 
USING (auth.uid() = provider_id)
WITH CHECK (auth.uid() = provider_id);

-- 4. CREATE: Helper Policy (Manage their provider's services)
-- Helpers need to match their provider_id in user_metadata or in the users table
CREATE POLICY "Helpers can manage provider services" ON public.services 
FOR ALL TO authenticated 
USING (
  provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
  OR 
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() 
    AND role = 'provider_helper' 
    AND public.users.provider_id = public.services.provider_id::text
  )
)
WITH CHECK (
  provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
  OR 
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() 
    AND role = 'provider_helper' 
    AND public.users.provider_id = public.services.provider_id::text
  )
);

-- 5. ENSURE: Standard View Policy (Anyone can see active, owners can see all)
DROP POLICY IF EXISTS "Anyone can view active services." ON public.services;
CREATE POLICY "Anyone can view active services." ON public.services 
FOR SELECT USING (
  status = 'active'
  OR auth.uid() = provider_id
  OR provider_id::text = (auth.jwt() -> 'user_metadata' ->> 'provider_id')
  OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
);
