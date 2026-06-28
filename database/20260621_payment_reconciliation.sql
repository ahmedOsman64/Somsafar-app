-- 20260621_payment_reconciliation.sql
-- Create a table to store the results of daily reconciliation runs.

CREATE TABLE IF NOT EXISTS public.reconciliation_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL DEFAULT 'WaafiPay',
    reconciled_date DATE NOT NULL DEFAULT CURRENT_DATE,
    summary JSONB NOT NULL DEFAULT '{}'::jsonb,
    discrepancies JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT CHECK (status IN ('MATCHED', 'DISCREPANCY_FOUND', 'SYSTEM_ERROR')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    created_by UUID REFERENCES auth.users(id)
);

-- Enable RLS
ALTER TABLE public.reconciliation_reports ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Admins can view reconciliation reports" 
ON public.reconciliation_reports FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Index for date-based retrieval
CREATE INDEX IF NOT EXISTS idx_reconciliation_date ON public.reconciliation_reports (reconciled_date);

-- Helper View for Admin Dashboard:
-- Shows bookings where the payment_status is 'pending' but there is a Successful transaction (Mismatch)
CREATE OR REPLACE VIEW public.view_payment_discrepancies 
WITH (security_invoker = true)
AS
SELECT 
    b.id as booking_id,
    b.traveler_id,
    b.service_title,
    b.total_price,
    b.payment_status as current_booking_payment_status,
    t.transaction_status as actual_transaction_status,
    t.reference_id,
    t.created_at as transaction_time
FROM public.bookings b
JOIN public.payment_transactions t ON b.id = t.booking_id
WHERE b.payment_status = 'pending' 
AND t.transaction_status = 'SUCCESSFUL';

