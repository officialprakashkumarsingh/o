import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import 'app_service.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int messageCount;
  final String? lastUserMessage;
  final bool? isPinned;
  List<Message>? messages; // Cache for messages

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.messageCount,
    this.lastUserMessage,
    this.isPinned,
    this.messages,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'] ?? 'New Chat',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isActive: json['is_active'] ?? true,
      messageCount: json['message_count'] ?? 0,
      lastUserMessage: json['last_user_message'],
      isPinned: json['is_pinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive,
      'message_count': messageCount,
    };
  }
}

class ChatHistoryService extends ChangeNotifier {
  static final ChatHistoryService _instance = ChatHistoryService._internal();
  static ChatHistoryService get instance => _instance;
  
  ChatHistoryService._internal();

  final _supabase = AppService.supabase;
  
  String? _currentSessionId;
  List<ChatSession> _sessions = [];
  bool _isLoading = false;
  
  String? get currentSessionId => _currentSessionId;
  List<ChatSession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  // Initialize and load sessions
  Future<void> initialize() async {
    await loadSessions();
    await getOrCreateActiveSession();
  }

  // Load all chat sessions for current user
  Future<void> loadSessions() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final response = await _supabase
          .from('chat_session_summaries')
          .select()
          .eq('user_id', userId)
          .order('is_pinned', ascending: false)
          .order('updated_at', ascending: false);
      
      _sessions = (response as List)
          .map((json) => ChatSession.fromJson(json))
          .toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading sessions: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get or create active session
  Future<String?> getOrCreateActiveSession() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      
      // Check for existing active session
      final existingSession = _sessions.firstWhere(
        (s) => s.isActive,
        orElse: () => ChatSession(
          id: '',
          title: 'New Chat',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: false,
          messageCount: 0,
        ),
      );
      
      if (existingSession.id.isNotEmpty) {
        _currentSessionId = existingSession.id;
        return _currentSessionId;
      }
      
      // Create new session
      final response = await _supabase
          .from('chat_sessions')
          .insert({
            'user_id': userId,
            'title': 'New Chat',
            'is_active': true,
          })
          .select()
          .single();
      
      _currentSessionId = response['id'];
      await loadSessions();
      return _currentSessionId;
    } catch (e) {
      print('Error getting/creating session: $e');
      return null;
    }
  }

  // Create new chat session
  Future<String?> createNewSession() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      
      // Deactivate current session
      if (_currentSessionId != null) {
        await _supabase
            .from('chat_sessions')
            .update({'is_active': false})
            .eq('id', _currentSessionId!);
      }
      
      // Create new session
      final response = await _supabase
          .from('chat_sessions')
          .insert({
            'user_id': userId,
            'title': 'New Chat',
            'is_active': true,
          })
          .select()
          .single();
      
      _currentSessionId = response['id'];
      await loadSessions();
      notifyListeners(); // This will trigger the ChatPage to clear messages
      return _currentSessionId;
    } catch (e) {
      print('Error creating new session: $e');
      return null;
    }
  }

  // Switch to a different session
  Future<List<Message>> switchToSession(String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      
      // Deactivate current session
      if (_currentSessionId != null && _currentSessionId != sessionId) {
        await _supabase
            .from('chat_sessions')
            .update({'is_active': false})
            .eq('id', _currentSessionId!);
      }
      
      // Activate new session
      await _supabase
          .from('chat_sessions')
          .update({'is_active': true})
          .eq('id', sessionId);
      
      _currentSessionId = sessionId;
      
      // Load messages for this session
      final messages = await loadSessionMessages(sessionId);
      
      await loadSessions();
      notifyListeners();
      
      return messages;
    } catch (e) {
      print('Error switching session: $e');
      return [];
    }
  }

  // Load messages for a specific session
  Future<List<Message>> loadSessionMessages(String sessionId) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);
      
      final messages = (response as List).map((json) {
        final type = json['role'] == 'user' 
            ? MessageType.user 
            : MessageType.assistant;
        
        return Message(
          id: json['id'],
          content: json['content'],
          type: type,
          timestamp: DateTime.parse(json['created_at']),
        );
      }).toList();
      
      // Cache messages in the session
      final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        _sessions[sessionIndex].messages = messages;
      }
      
      return messages;
    } catch (e) {
      print('Error loading messages: $e');
      return [];
    }
  }
  
  // Load messages for all sessions (for searching)
  Future<void> loadAllSessionMessages() async {
    try {
      for (var session in _sessions) {
        if (session.messages == null) {
          session.messages = await loadSessionMessages(session.id);
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading all messages: $e');
    }
  }

  // Save message to current session
  Future<void> saveMessage(Message message, {String? modelName}) async {
    try {
      // Don't create a new session here - it should already exist
      if (_currentSessionId == null) {
        print('Warning: No active session for saving message');
        return;
      }
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await _supabase.from('chat_messages').insert({
        'session_id': _currentSessionId,
        'user_id': userId,
        'content': message.content,
        'role': message.type == MessageType.user ? 'user' : 'assistant',
        'model_name': modelName,
      });
      
      // Don't reload sessions here - it causes issues with streaming
      // Just update the message count locally if needed
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  // Delete a session
  Future<void> deleteSession(String sessionId) async {
    try {
      await _supabase
          .from('chat_sessions')
          .delete()
          .eq('id', sessionId);
      
      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
        await getOrCreateActiveSession();
      }
      
      await loadSessions();
      notifyListeners();
    } catch (e) {
      print('Error deleting session: $e');
    }
  }

  // Clear all sessions for current user
  Future<void> clearAllSessions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await _supabase
          .from('chat_sessions')
          .delete()
          .eq('user_id', userId);
      
      _sessions.clear();
      _currentSessionId = null;
      await getOrCreateActiveSession();
      notifyListeners();
    } catch (e) {
      print('Error clearing sessions: $e');
    }
  }
  
  // Rename a session
  Future<void> renameSession(String sessionId, String newTitle) async {
    try {
      await _supabase
          .from('chat_sessions')
          .update({'title': newTitle})
          .eq('id', sessionId);
      
      await loadSessions();
      notifyListeners();
    } catch (e) {
      print('Error renaming session: $e');
    }
  }
  
  // Toggle pin status of a session
  Future<void> togglePinSession(String sessionId) async {
    try {
      final session = _sessions.firstWhere((s) => s.id == sessionId);
      final newPinStatus = !(session.isPinned ?? false);
      
      await _supabase
          .from('chat_sessions')
          .update({'is_pinned': newPinStatus})
          .eq('id', sessionId);
      
      await loadSessions();
      notifyListeners();
    } catch (e) {
      print('Error toggling pin status: $e');
    }
  }
}