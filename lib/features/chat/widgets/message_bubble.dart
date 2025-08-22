import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/message_model.dart';
import '../../../core/models/image_message_model.dart';
import '../../../core/models/vision_message_model.dart';
import '../../../core/models/diagram_message_model.dart';
import '../../../core/models/presentation_message_model.dart';
import '../../../core/models/chart_message_model.dart';
import '../../../core/models/flashcard_message_model.dart';
import '../../../core/models/quiz_message_model.dart';
import '../../../shared/widgets/markdown_message.dart';
import '../../../shared/widgets/thinking_animation.dart';
import '../../../shared/widgets/diagram_preview.dart';
import '../../../shared/widgets/presentation_preview.dart';
import '../../../shared/widgets/chart_preview.dart';
import '../../../shared/widgets/flashcard_preview.dart';
import '../../../shared/widgets/quiz_preview.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onExport;
  final String? modelName;
  final String? userMessage;
  final String? aiModel;

  const MessageBubble({
    super.key,
    required this.message,
    this.onCopy,
    this.onRegenerate,
    this.onExport,
    this.modelName,
    this.userMessage,
    this.aiModel,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  bool _showActions = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _exportTextAsImage() async {
    try {
      // Show exporting notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Preparing conversation export...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }

      // Get the user message and AI model info
      final userMessage = widget.userMessage ?? '';
      final aiModel = widget.aiModel ?? 'AI Assistant';
      final timestamp = widget.message.timestamp;
      
      // Create a GlobalKey for the export widget
      final exportKey = GlobalKey();
      
      // Create a custom widget for export with all context
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) => Stack(
          children: [
            Positioned(
              left: -1000,
              child: Material(
                child: Container(
                  width: 800,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: RepaintBoundary(
                    key: exportKey,
                    child: _ExportMessageWidget(
                      userMessage: userMessage,
                      aiMessage: widget.message,
                      aiModel: aiModel,
                      timestamp: timestamp,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      // Wait for the widget to render
      await Future.delayed(const Duration(milliseconds: 100));

      // Find and capture the export widget
      final RenderRepaintBoundary? boundary = 
          exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        // Fallback to original message capture
        final originalBoundary = _repaintBoundaryKey.currentContext
            ?.findRenderObject() as RenderRepaintBoundary?;
        
        if (originalBoundary == null) {
          throw Exception('Unable to capture message');
        }
        
        final image = await originalBoundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) throw Exception('Unable to convert to image');
        
        final pngBytes = byteData.buffer.asUint8List();
        Navigator.of(context).pop();
        await _shareImage(pngBytes);
        return;
      }

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Unable to convert to image');
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();
      Navigator.of(context).pop();
      
      await _shareImage(pngBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
      }
    }
  }
  
  Future<void> _shareImage(Uint8List pngBytes) async {
    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/message_$timestamp.png');
    await file.writeAsBytes(pngBytes);

    // Share the image
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Conversation from AhamAI',
    );

    // Clean up after delay
    Future.delayed(const Duration(seconds: 10), () {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Conversation exported as image!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.type == MessageType.user;
    final isStreaming = widget.message.isStreaming;
    final hasError = widget.message.hasError;

    return GestureDetector(
      onTap: () {
        // Haptic feedback on tap
        HapticFeedback.lightImpact();
      },
      onDoubleTap: isUser ? _copyToClipboard : null,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message content
          RepaintBoundary(
            key: _repaintBoundaryKey,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
            padding: isUser 
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                : const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            decoration: isUser
                ? BoxDecoration(
                    color: _getBubbleColor(context, isUser, hasError),
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: const Radius.circular(4),
                    ),
                    border: hasError
                        ? Border.all(
                            color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                            width: 1,
                          )
                        : null,
                  )
                : null, // No decoration for AI messages (transparent)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image content for image messages
                if (widget.message is ImageMessage) ...[
                  _buildImageContent(widget.message as ImageMessage),
                ] else if (widget.message is VisionMessage) ...[
                  _buildVisionContent(widget.message as VisionMessage),
                ] else if (widget.message is DiagramMessage) ...[
                  _buildDiagramContent(widget.message as DiagramMessage),
                ] else if (widget.message is PresentationMessage) ...[
                  _buildPresentationContent(widget.message as PresentationMessage),
                ] else if (widget.message is ChartMessage) ...[
                  _buildChartContent(widget.message as ChartMessage),
                ] else if (widget.message is FlashcardMessage) ...[
                  _buildFlashcardContent(widget.message as FlashcardMessage),
                ] else if (widget.message is QuizMessage) ...[
                  _buildQuizContent(widget.message as QuizMessage),
                ] else ...[
                  // Regular message content with markdown support
                  MarkdownMessage(
                    content: widget.message.content,
                    isUser: isUser,
                    isStreaming: isStreaming,
                  ),
                ],
                
                // Streaming indicator - only show if no content yet
                // Don't show for DiagramMessage, PresentationMessage, or ChartMessage
                if (isStreaming && 
                    widget.message.content.isEmpty &&
                    widget.message is! DiagramMessage &&
                    widget.message is! PresentationMessage &&
                    widget.message is! ChartMessage &&
                    widget.message is! FlashcardMessage &&
                    widget.message is! QuizMessage) ...[
                  const SizedBox(height: 8),
                  ThinkingAnimation(
                    color: Theme.of(context).colorScheme.primary,
                    size: 8,
                  ),
                ],
              ],
            ),
          ),
        ),

          // Actions - Show different actions based on message type
          if (!isUser && !isStreaming && !hasError)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // For image messages, show export
                  if (widget.message is ImageMessage) ...[
                    if (widget.onExport != null)
                      _ActionButton(
                        icon: Icons.download_outlined,
                        label: 'Export',
                        onPressed: widget.onExport!,
                      ),
                  ] else if (widget.message is DiagramMessage) ...[
                    // Don't show export here - it's already in the diagram preview
                  ] else if (widget.message is PresentationMessage) ...[
                    // Don't show export here - it's already in the presentation preview
                  ] else if (widget.message is ChartMessage) ...[
                    // Don't show export here - it's already in the chart preview
                  ] else if (widget.message is FlashcardMessage) ...[
                    // Don't show export here - it's already in the flashcard preview
                  ] else if (widget.message is QuizMessage) ...[
                    // Don't show export here - it's already in the quiz preview
                  ] else ...[
                    // For text messages, show all options
                    // Copy - always visible for AI messages
                    if (widget.onCopy != null)
                      _ActionButton(
                        icon: Icons.content_copy_outlined,
                        label: 'Copy',
                        onPressed: widget.onCopy!,
                      ),
                    
                    // Regenerate - always visible for AI messages
                    if (widget.onRegenerate != null) ...[
                      if (widget.onCopy != null) const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.refresh_outlined,
                        label: 'Regenerate',
                        onPressed: widget.onRegenerate!,
                      ),
                    ],
                    
                    // Export as Image - always visible for AI messages
                    if (widget.onExport != null) ...[
                      if (widget.onCopy != null || widget.onRegenerate != null) 
                        const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.image_outlined,
                        label: 'Export',
                        onPressed: () => _exportTextAsImage(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          

        ],
      ),
    );
  }

  Color _getBubbleColor(BuildContext context, bool isUser, bool hasError) {
    if (hasError) {
      return Theme.of(context).colorScheme.error.withOpacity(0.1);
    }
    if (isUser) {
      return Theme.of(context).colorScheme.primary;
    }
    return Theme.of(context).colorScheme.surfaceVariant;
  }

  Color _getTextColor(BuildContext context, bool isUser, bool hasError) {
    if (hasError) {
      return Theme.of(context).colorScheme.error;
    }
    if (isUser) {
      return Theme.of(context).colorScheme.onPrimary;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Widget _buildImageContent(ImageMessage imageMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt text
        Text(
          'Image: ${imageMessage.prompt}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Model name
        Text(
          'Model: ${imageMessage.model}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Image or loading state
        if (imageMessage.isGenerating)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Generating...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          )
        else if (imageMessage.imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImageWidget(imageMessage.imageUrl),
          ),
      ],
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    // Handle data URLs (base64 encoded images)
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64Data = imageUrl.split(',')[1];
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          width: 280,
          height: 280,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageError();
          },
        );
      } catch (e) {
        return _buildImageError();
      }
    }
    
    // Handle regular network URLs
    return Image.network(
      imageUrl,
      width: 200,
      height: 200,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                    loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildImageError();
      },
    );
  }

  Widget _buildImageError() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionContent(VisionMessage visionMessage) {
    final isUser = visionMessage.type == MessageType.user;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isUser) ...[
          // Show the uploaded image for user messages
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildUploadedImage(visionMessage.imageData),
          ),
          const SizedBox(height: 12),
          // Show the user's question
          Text(
            visionMessage.analysisPrompt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          // For AI responses, show the analysis result
          MarkdownMessage(
            content: visionMessage.content,
            isUser: false,
            isStreaming: false,
          ),
        ],
      ],
    );
  }

  Widget _buildDiagramContent(DiagramMessage diagramMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (diagramMessage.prompt.isNotEmpty) ...[
          Text(
            'Diagram: ${diagramMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the diagram preview
        if (diagramMessage.mermaidCode.isNotEmpty)
          DiagramPreview(
            mermaidCode: diagramMessage.mermaidCode,
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Failed to generate diagram. Please try again.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresentationContent(PresentationMessage presentationMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (presentationMessage.prompt.isNotEmpty) ...[
          Text(
            'Presentation: ${presentationMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the presentation preview
        if (presentationMessage.slides.isNotEmpty)
          PresentationPreview(
            slides: presentationMessage.slides,
            title: presentationMessage.prompt,
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to generate presentation slides',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildChartContent(ChartMessage chartMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (chartMessage.prompt.isNotEmpty) ...[
          Text(
            'Chart: ${chartMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the chart preview
        if (chartMessage.chartConfig.isNotEmpty)
          ChartPreview(
            chartConfig: chartMessage.chartConfig,
            prompt: chartMessage.prompt,
          )
        else if (chartMessage.isStreaming)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to generate chart',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFlashcardContent(FlashcardMessage flashcardMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (flashcardMessage.prompt.isNotEmpty) ...[
          Text(
            'Flashcards: ${flashcardMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the flashcard preview
        if (flashcardMessage.flashcards.isNotEmpty)
          FlashcardPreview(
            flashcards: flashcardMessage.flashcards,
            title: flashcardMessage.prompt,
          )
        else if (flashcardMessage.isStreaming)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to generate flashcards',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuizContent(QuizMessage quizMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the prompt
        if (quizMessage.prompt.isNotEmpty) ...[
          Text(
            'Quiz: ${quizMessage.prompt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Show the quiz preview
        if (quizMessage.questions.isNotEmpty)
          QuizPreview(
            questions: quizMessage.questions,
            title: quizMessage.prompt,
          )
        else if (quizMessage.isStreaming)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to generate quiz',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadedImage(String imageData) {
    try {
      final base64Data = imageData.split(',')[1];
      final bytes = base64Decode(base64Data);
      return Image.memory(
        bytes,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Invalid image',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Invalid image',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _ExportMessageWidget extends StatelessWidget {
  final String userMessage;
  final Message aiMessage;
  final String aiModel;
  final DateTime timestamp;
  
  const _ExportMessageWidget({
    required this.userMessage,
    required this.aiMessage,
    required this.aiModel,
    required this.timestamp,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with app name and timestamp
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AhamAI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      aiModel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      dateFormat,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // User message
          if (userMessage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // AI response
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      aiModel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                MarkdownMessage(
                  content: aiMessage.content,
                  isUser: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
