import 'message_model.dart';

class ChartMessage extends Message {
  final String prompt;
  final String chartConfig;
  final String chartType;

  ChartMessage({
    required super.id,
    required this.prompt,
    required this.chartConfig,
    this.chartType = 'bar',
    required super.timestamp,
    super.isStreaming = false,
    super.hasError = false,
  }) : super(
          content: chartConfig,
          type: MessageType.assistant,
        );

  @override
  ChartMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    bool? hasError,
    String? prompt,
    String? chartConfig,
    String? chartType,
  }) {
    return ChartMessage(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      chartConfig: (content != null && content != this.content)
          ? content
          : (chartConfig ?? this.chartConfig),
      chartType: chartType ?? this.chartType,
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
      'chartConfig': chartConfig,
      'chartType': chartType,
    };
  }

  factory ChartMessage.fromJson(Map<String, dynamic> json) {
    return ChartMessage(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      chartConfig: json['chartConfig'] as String,
      chartType: json['chartType'] as String? ?? 'bar',
      timestamp: DateTime.parse(json['timestamp'] as String),
      isStreaming: json['isStreaming'] as bool? ?? false,
      hasError: json['hasError'] as bool? ?? false,
    );
  }
}