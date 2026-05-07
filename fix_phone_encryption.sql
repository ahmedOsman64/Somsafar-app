-- SQL to disable phone number encryption and restore original numbers
-- Run this in your Supabase SQL Editor

-- 1. Drop the encryption trigger to stop new encryptions
DROP TRIGGER IF EXISTS tr_encrypt_phone ON public.users;

-- 2. Restore the original phone numbers by decrypting the encrypted_phone column
-- Note: We use the same key used during encryption ('somsafar-secure-key-2026')
UPDATE public.users 
SET phone = pgp_sym_decrypt(encrypted_phone, 'somsafar-secure-key-2026')
WHERE phone = 'ENCRYPTED' AND encrypted_phone IS NOT NULL;

-- 3. (Optional) Remove the encryption column and helper function to clean up the schema
-- ALTER TABLE public.users DROP COLUMN IF EXISTS encrypted_phone;
-- DROP FUNCTION IF EXISTS public.encrypt_user_phone();

-- 4. Verify the restoration
-- SELECT name, phone FROM public.users LIMIT 10;
