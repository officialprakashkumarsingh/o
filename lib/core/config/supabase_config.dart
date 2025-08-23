import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://mdoksiisbokvmqsdcguu.supabase.co';
  static final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kb2tzaWlzYm9rdm1xc2RjZ3V1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU4NTU3MzcsImV4cCI6MjA3MTQzMTczN30.Sq2eDHc_NgU9Br0zsWdYOr98WSIJS6AsNYaUt3NkbsU';
}