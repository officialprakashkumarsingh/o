import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearchService {
  static const String baseUrl = 'https://googlesearchapi.nepcoderapis.workers.dev';
  
  static Future<List<SearchResult>> search({
    required String query,
    int numResults = 5,
  }) async {
    try {
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'q': query,
          'num': numResults.toString(),
        },
      );
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        return results
            .map((result) => SearchResult.fromJson(result))
            .toList();
      }
      
      return [];
    } catch (e) {
      print('Web search error: $e');
      return [];
    }
  }
  
  static String formatSearchResults(List<SearchResult> results) {
    if (results.isEmpty) {
      return 'No search results found.';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Here are the current search results:');
    buffer.writeln();
    
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.writeln('${i + 1}. **${result.title}**');
      buffer.writeln('   ${result.snippet}');
      buffer.writeln('   Source: ${result.link}');
      buffer.writeln();
    }
    
    buffer.writeln('Please provide a comprehensive response based on this current information.');
    
    return buffer.toString();
  }
  
  static String getCurrentDateTime() {
    final now = DateTime.now();
    return 'Current date and time: ${now.toString().split('.').first} UTC';
  }
}

class SearchResult {
  final String title;
  final String snippet;
  final String link;
  
  const SearchResult({
    required this.title,
    required this.snippet,
    required this.link,
  });
  
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      link: json['link'] as String? ?? '',
    );
  }
  
  @override
  String toString() {
    return 'SearchResult(title: $title, link: $link)';
  }
}