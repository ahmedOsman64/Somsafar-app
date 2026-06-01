-- SomSafar: Restore Phone Numbers to Plain Text
-- This script decrypts the phone numbers in the public.users table and restores them to the 'phone' column.
-- It also drops the trigger that causes the encryption.

-- 1. Drop the trigger to prevent re-encryption during update
DROP TRIGGER IF EXISTS tr_encrypt_phone ON public.users;

-- 2. Restore phone numbers from the encrypted_phone column
-- Use the established decryption key: 'somsafar-secure-key-2026'
UPDATE public.users
SET phone = pgp_sym_decrypt(encrypted_phone, 'somsafar-secure-key-2026')
WHERE encrypted_phone IS NOT NULL 
AND (phone = 'ENCRYPTED' OR phone IS NULL);

-- 3. (Optional) Cleanup: Comment out the next line if you want to keep the backup column
-- ALTER TABLE public.users DROP COLUMN IF EXISTS encrypted_phone;

-- Success Message
SELECT 'Phone numbers have been successfully restored to plain text.' as result;
