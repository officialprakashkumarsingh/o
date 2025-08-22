import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class VisionService {
  static const String baseUrl = 'https://ahamai-api.officialprakashkrsingh.workers.dev';
  static const String authToken = 'ahamaibyprakash25';
  
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $authToken',
  };

  // Get available vision models
  static Future<List<VisionModel>> getVisionModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v1/vision/models'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return List<VisionModel>.from(
            data['data'].map((model) => VisionModel.fromJson(model)),
          );
        }
      }
      
      return [];
    } catch (e) {
      print('Error fetching vision models: $e');
      return [];
    }
  }

  // Analyze image with vision model
  static Future<Stream<String>> analyzeImage({
    required String prompt,
    required String imageData,
    required String model,
  }) async {
    try {
      final messages = [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': prompt,
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': imageData,
              },
            },
          ],
        },
      ];

      final requestBody = {
        'model': model,
        'messages': messages,
        'stream': false, // Vision API doesn't seem to support streaming properly
        'max_tokens': 2000,
        'temperature': 0.7,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/v1/chat/completions'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final controller = StreamController<String>();
        
        try {
          final data = jsonDecode(response.body);
          final content = data['choices']?[0]?['message']?['content'];
          
          if (content != null && content.toString().isNotEmpty) {
            controller.add(content.toString());
          } else {
            controller.add('I was unable to analyze the image. Please try again.');
          }
        } catch (e) {
          print('Error parsing vision response: $e');
          print('Response body: ${response.body}');
          controller.add('Sorry, I encountered an error while analyzing the image. Please try again.');
        }
        
        controller.close();
        return controller.stream;
      } else {
        print('Vision API error: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Vision analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in vision analysis: $e');
      // Return error stream
      final controller = StreamController<String>();
      controller.add('Sorry, I encountered an error while analyzing the image. Please try again.');
      controller.close();
      return controller.stream;
    }
  }

  // Get the best available vision model
  static Future<String?> getBestVisionModel() async {
    try {
      final visionModels = await getVisionModels();
      if (visionModels.isNotEmpty) {
        // Return the first available vision model
        return visionModels.first.id;
      }
    } catch (e) {
      print('Error getting vision models: $e');
    }
    return null;
  }

  // Check if a model supports vision
  static bool isVisionModel(String modelId) {
    // For now, we'll check if it's the vision model we know about
    // This could be expanded to check against the vision models list
    return modelId.toLowerCase().contains('gemini') || 
           modelId.toLowerCase().contains('vision') ||
           modelId.toLowerCase().contains('gpt-4') ||
           modelId.toLowerCase().contains('claude-3');
  }
}

class VisionModel {
  final String id;
  final String name;
  final String provider;
  final List<String> capabilities;
  final int maxTokens;
  final List<String> supportedFormats;

  const VisionModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.capabilities,
    required this.maxTokens,
    required this.supportedFormats,
  });

  factory VisionModel.fromJson(Map<String, dynamic> json) {
    return VisionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String,
      capabilities: List<String>.from(json['capabilities'] ?? []),
      maxTokens: json['max_tokens'] as int? ?? 4000,
      supportedFormats: List<String>.from(json['supported_formats'] ?? []),
    );
  }

  @override
  String toString() {
    return 'VisionModel(id: $id, name: $name, provider: $provider)';
  }
}