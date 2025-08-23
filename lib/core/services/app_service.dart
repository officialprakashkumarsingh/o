import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'ad_service.dart';

class AppService {
  static SharedPreferences? _prefs;
  
  static SharedPreferences get prefs => _prefs!;
  static final supabase = Supabase.instance.client;
  
  static Future<void> initialize() async {
    try {
      // Initialize Supabase
      print('Initializing Supabase...');
      print('URL: ${SupabaseConfig.supabaseUrl}');
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      print('Supabase initialized successfully');
    } catch (e) {
      print('Error initializing Supabase: $e');
      // Continue without Supabase if it fails
    }
    
    try {
      // Initialize shared preferences
      print('Initializing SharedPreferences...');
      _prefs = await SharedPreferences.getInstance();
      print('SharedPreferences initialized successfully');
    } catch (e) {
      print('Error initializing SharedPreferences: $e');
      rethrow;
    }
    
    try {
      // Initialize Ad service
      print('Initializing Ad service...');
      await AdService.instance.initialize();
      print('Ad service initialized successfully');
    } catch (e) {
      print('Error initializing Ad service: $e');
      // Continue without ads if it fails
    }
    
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
    
    // Enable edge-to-edge
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }
}