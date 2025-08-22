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

  @override
  Message copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
  }) {
    // For WebSearchMessage, we treat content as searchResults
    return WebSearchMessage(
      id: id ?? this.id,
      isSearching: isStreaming ?? this.isSearching,
      searchQuery: searchQuery,
      searchResults: content ?? this.searchResults,
    );
  }
}