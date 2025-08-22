import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppService {
  static SharedPreferences? _prefs;
  
  static SharedPreferences get prefs => _prefs!;
  
  static Future<void> initialize() async {
    // Initialize shared preferences
    _prefs = await SharedPreferences.getInstance();
    
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