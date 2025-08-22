import 'dart:async';
import 'dart:convert';

import '../models/user_model.dart';
import 'app_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;
  
  AuthService._internal();

  static const String _userKey = 'current_user';
  
  final StreamController<User?> _userController = StreamController<User?>.broadcast();
  Stream<User?> get userStream => _userController.stream;
  
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    await _loadUserFromStorage();
  }

  Future<User?> signIn(String email, String password) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 800));
      
      // For demo purposes, accept any email/password
      final user = User(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        name: email.split('@').first,
        createdAt: DateTime.now(),
      );
      
      await _saveUserToStorage(user);
      _currentUser = user;
      _userController.add(user);
      
      return user;
    } catch (e) {
      return null;
    }
  }

  Future<User?> signUp(String name, String email, String password) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 1000));
      
      final user = User(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );
      
      await _saveUserToStorage(user);
      _currentUser = user;
      _userController.add(user);
      
      return user;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await AppService.prefs.remove(_userKey);
      _currentUser = null;
      _userController.add(null);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadUserFromStorage() async {
    try {
      final userJson = AppService.prefs.getString(_userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        _currentUser = User.fromJson(userData);
        _userController.add(_currentUser);
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveUserToStorage(User user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      await AppService.prefs.setString(_userKey, userJson);
    } catch (e) {
      // Handle error
    }
  }

  void dispose() {
    _userController.close();
  }
}