import 'message_model.dart';

class WebSearchMessage extends Message {
  final bool isSearching;
  final String? searchQuery;
  final String? searchResults;

  WebSearchMessage({
    required String id,
    this.isSearching = true,
    this.searchQuery,
    this.searchResults,
  }) : super(
          id: id,
          content: searchResults ?? '',
          type: MessageType.assistant,
          timestamp: DateTime.now(),
          isStreaming: isSearching,
        );

  WebSearchMessage copyWith({
    bool? isSearching,
    String? searchQuery,
    String? searchResults,
  }) {
    return WebSearchMessage(
      id: id,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
    );
  }
}