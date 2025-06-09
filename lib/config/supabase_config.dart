import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String SUPABASE_URL = 'https://jusznuslfjfnabaqnvqb.supabase.co';
  static const String SUPABASE_ANON_KEY =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1c3pudXNsZmpmbmFiYXFudnFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc5OTYxNDAsImV4cCI6MjA2MzU3MjE0MH0.XNn7YlJXRniWF75UefUEA69_OaNmtj0D1Tz_Zcnv_2s';

  // url: 'https://jusznuslfjfnabaqnvqb.supabase.co',
  // anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1c3pudXNsZmpmbmFiYXFudnFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc5OTYxNDAsImV4cCI6MjA2MzU3MjE0MH0.XNn7YlJXRniWF75UefUEA69_OaNmtj0D1Tz_Zcnv_2s',
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SUPABASE_URL,
      anonKey: SUPABASE_ANON_KEY,
    );
  }
}
