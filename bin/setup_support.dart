import 'package:supabase/supabase.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  print('Loading environment variables...');
  await dotenv.load(fileName: 'assets/env');
  
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseKey == null) {
    print('Error: Missing Supabase credentials in assets/env');
    exit(1);
  }

  print('Connecting to Supabase...');
  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  print('Executing SQL to create support_tickets table and policies...');
  
  try {
    // Note: To execute raw SQL like this, we'll need the service role key or use the RPC function if available.
    // If not, we might need to instruct the user to run this in the Supabase SQL editor.
    final sql = '''
      -- Create support_tickets table if it doesn't exist
      CREATE TABLE IF NOT EXISTS support_tickets (
        id UUID PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        user_name TEXT NOT NULL,
        user_email TEXT NOT NULL,
        issue_type TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        priority TEXT NOT NULL DEFAULT 'medium',
        messages JSONB DEFAULT '[]'::jsonb,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      -- Enable Row Level Security
      ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

      -- Create policies
      -- Users can insert their own tickets
      CREATE POLICY IF NOT EXISTS "Users can insert their own tickets"
        ON support_tickets FOR INSERT
        WITH CHECK (auth.uid() = user_id);

      -- Users can view their own tickets
      CREATE POLICY IF NOT EXISTS "Users can view their own tickets"
        ON support_tickets FOR SELECT
        USING (auth.uid() = user_id);

      -- Optionally: Add service role policies or admin specific logic if needed
      -- (Assuming authenticated users with an 'admin' role could view/edit all, but we'll stick to basic RLS and rely on service_role for admins if needed, or adjust based on existing pattern)
    ''';
    
    // Attempting to use a generic RPC function 'exec_sql' if implemented in their backend
    // If this fails, we will notify the user to copy-paste the SQL into their Supabase dashboard.
    final response = await supabase.rpc('exec_sql', params: {'sql_query': sql});
    print('SQL Execution Response: $response');
    print('Table creation successful.');

  } catch (e) {
    print('Failed to execute SQL via RPC. Error: $e');
    print('---');
    print('Please run the following SQL snippet in your Supabase SQL Editor:');
    print('''
CREATE TABLE IF NOT EXISTS support_tickets (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  user_email TEXT NOT NULL,
  issue_type TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'open',
  priority TEXT NOT NULL DEFAULT 'medium',
  messages JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own tickets" ON support_tickets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view their own tickets" ON support_tickets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own tickets" ON support_tickets FOR UPDATE USING (auth.uid() = user_id);

-- Depending on your admin setup, you might need a policy for admins to view/edit all tickets.
    ''');
    
    // We will now test if the table already exists anyway
    try {
        final check = await supabase.from('support_tickets').select().limit(1);
        print('Wait, support_tickets table EXISTS: $check');
    } catch(err) {
        print('Confirmed: support_tickets table missing or no access. $err');
    }
  }

  exit(0);
}
