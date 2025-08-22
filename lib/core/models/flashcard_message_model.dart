import 'message_model.dart';

class FlashcardItem {
  final String question;
  final String answer;
  final String? explanation;

  FlashcardItem({
    required this.question,
    required this.answer,
    this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
      if (explanation != null) 'explanation': explanation,
    };
  }

  factory FlashcardItem.fromJson(Map<String, dynamic> json) {
    return FlashcardItem(
      question: json['question'] as String,
      answer: json['answer'] as String,
      explanation: json['explanation'] as String?,
    );
  }
}

class FlashcardMessage extends Message {
  final String prompt;
  final List<FlashcardItem> flashcards;

  FlashcardMessage({
    required super.id,
    required this.prompt,
    required this.flashcards,
    required super.timestamp,
    super.isStreaming = false,
    super.hasError = false,
  }) : super(
          content: flashcards.map((f) => 'Q: ${f.question}\nA: ${f.answer}').join('\n\n'),
          type: MessageType.assistant,
        );

  @override
  FlashcardMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
    String? prompt,
    List<FlashcardItem>? flashcards,
  }) {
    return FlashcardMessage(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      flashcards: flashcards ?? this.flashcards,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      hasError: hasError ?? this.hasError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.toString(),
      'timestamp': timestamp.toIso8601String(),
      'isStreaming': isStreaming,
      'hasError': hasError,
      'prompt': prompt,
      'flashcards': flashcards.map((f) => f.toJson()).toList(),
    };
  }

  factory FlashcardMessage.fromJson(Map<String, dynamic> json) {
    return FlashcardMessage(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      flashcards: (json['flashcards'] as List)
          .map((f) => FlashcardItem.fromJson(f as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isStreaming: json['isStreaming'] as bool? ?? false,
      hasError: json['hasError'] as bool? ?? false,
    );
  }
}