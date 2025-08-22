import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://ahamai-api.officialprakashkrsingh.workers.dev';
  static const String authToken = 'ahamaibyprakash25';
  
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $authToken',
  };

  // Get available models
  static Future<List<String>> getModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v1/models'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return List<String>.from(
            data['data'].map((model) => model['id'] ?? model['name'] ?? ''),
          ).where((model) => model.isNotEmpty).toList();
        }
      }
      
      // Fallback models if API fails
      return [
        'claude-3-5-sonnet',
        'claude-3-7-sonnet',
        'claude-sonnet-4',
        'claude-3-5-sonnet-ashlynn',
      ];
    } catch (e) {
      // Return fallback models on error
      return [
        'claude-3-5-sonnet',
        'claude-3-7-sonnet',
        'claude-sonnet-4',
        'claude-3-5-sonnet-ashlynn',
      ];
    }
  }

  // Send chat message
  static Future<Stream<String>> sendMessage({
    required String message,
    required String model,
    List<Map<String, String>>? conversationHistory,
    String? systemPrompt,
  }) async {
    try {
      final messages = <Map<String, String>>[];
      
      // Add system prompt if provided
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': systemPrompt,
        });
      }
      
      // Add conversation history
      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }
      
      // Add current message
      messages.add({
        'role': 'user',
        'content': message,
      });

      final requestBody = {
        'model': model,
        'messages': messages,
        'stream': true,
        'max_tokens': 4000,
        'temperature': 0.7,
      };

      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/v1/chat/completions'),
      );
      
      request.headers.addAll(_headers);
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final controller = StreamController<String>();
        
        streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .where((line) => line.isNotEmpty && line.startsWith('data: '))
            .listen(
          (line) {
            try {
              final data = line.substring(6); // Remove 'data: ' prefix
              if (data.trim() == '[DONE]') {
                controller.close();
                return;
              }
              
              final json = jsonDecode(data);
              final delta = json['choices']?[0]?['delta'];
              final content = delta?['content'] ?? '';
              
              if (content.isNotEmpty) {
                controller.add(content);
              }
            } catch (e) {
              // Skip malformed chunks
            }
          },
          onError: (error) => controller.addError(error),
          onDone: () => controller.close(),
        );
        
        return controller.stream;
      } else {
        throw HttpException('Failed to send message: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  // Generate image (if supported by your API)
  static Future<String?> generateImage({
    required String prompt,
    String model = 'flux',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/v1/images/generations'),
        headers: _headers,
        body: jsonEncode({
          'prompt': prompt,
          'model': model,
          'size': '1024x1024',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']?[0]?['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}