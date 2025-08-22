import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/message_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/template_service.dart';
import '../../../core/services/message_mode_service.dart';
import '../../../core/services/model_service.dart';
import '../../../core/services/image_service.dart';
import '../../../core/services/web_search_service.dart';
import '../../../core/services/export_service.dart';
import '../../../core/services/vision_service.dart';
import '../../../core/models/image_message_model.dart';
import '../../../core/models/vision_message_model.dart';
import '../../../core/models/diagram_message_model.dart';
import '../../../core/models/presentation_message_model.dart';
import '../../../core/models/chart_message_model.dart';
import '../../../core/models/flashcard_message_model.dart';
import '../../../core/models/quiz_message_model.dart';
import '../../../core/services/diagram_service.dart';
import '../../../core/services/chart_service.dart';
import '../../../core/services/flashcard_service.dart';
import '../../../core/services/quiz_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/presentation_preview.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/template_selector.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  
  bool _isLoading = false;
  bool _showTemplates = false;
  bool _showScrollToBottom = false;
  bool _userIsScrolling = false;
  bool _autoScrollEnabled = true;
  
  // For stopping streams
  Stream<String>? _currentStream;

  @override
  void initState() {
    super.initState();
    ModelService.instance.loadModels();
    ImageService.instance.loadModels();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final isAtBottom = _scrollController.offset >= 
                     _scrollController.position.maxScrollExtent - 100;
    
    // Detect if user is manually scrolling
    if (_scrollController.position.isScrollingNotifier.value) {
      _userIsScrolling = true;
      // Re-enable auto scroll if user scrolls to bottom
      if (isAtBottom) {
        _autoScrollEnabled = true;
        _userIsScrolling = false;
      } else {
        _autoScrollEnabled = false;
      }
    }
    
    if (isAtBottom != !_showScrollToBottom) {
      setState(() {
        _showScrollToBottom = !isAtBottom;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ModelService.instance,
      builder: (context, _) {
        final modelService = ModelService.instance;
        
        return Stack(
          children: [
            Column(
              children: [
                // Chat messages
                Expanded(
                  child: _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),
                ),

                // Templates quick access
                if (_showTemplates)
                  _buildTemplateQuickAccess(),

                            // Input area
            ChatInput(
              controller: _inputController,
              selectedModel: modelService.selectedModel,
              onSendMessage: _handleSendMessage,
              onGenerateImage: _handleImageGeneration,
              onGenerateDiagram: _handleDiagramGeneration,
              onGeneratePresentation: _handlePresentationGeneration,
              onGenerateChart: _handleChartGeneration,
              onGenerateFlashcards: _handleFlashcardGeneration,
              onGenerateQuiz: _handleQuizGeneration,
              onVisionAnalysis: _handleVisionAnalysis,
              onStopStreaming: _stopStreaming,
              onTemplateRequest: () {
                setState(() {
                  _showTemplates = !_showTemplates;
                });
              },
              isLoading: _isLoading,
              enabled: modelService.selectedModel.isNotEmpty && !modelService.isLoading,
            ),
              ],
            ),
        
        // Scroll to bottom button - hide during streaming
        if (_showScrollToBottom && !_isLoading)
          Positioned(
            bottom: 120, // Higher above input area
            right: 16,
            child: AnimatedScale(
              scale: _showScrollToBottom && !_isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Material(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(28),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.2),
                child: InkWell(
                  onTap: _scrollToBottom,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      },
    );
  }

  Widget _buildEmptyState() {
    final user = AuthService.instance.currentUser;
    final userName = user?.name ?? 'there';
    String greeting = '';
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 12) {
      greeting = 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
    } else if (hour >= 17 && hour < 21) {
      greeting = 'Good evening';
    } else {
      greeting = 'Good night';
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simple greeting text without background
          Text(
            '$greeting, $userName!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How can I help you today?',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Template shortcut button
          Material(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _showTemplateSelector,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Browse Templates',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateQuickAccess() {
    final recentTemplates = TemplateService.instance.templates.take(5).toList();
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentTemplates.length + 1, // +1 for "More" button
        itemBuilder: (context, index) {
          if (index == recentTemplates.length) {
            // More button
            return Container(
              margin: const EdgeInsets.only(left: 8),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _showTemplateSelector,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'More',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          
          final template = recentTemplates[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _handleTemplateSelection(template.content),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    template.shortcut,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTemplateSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TemplateSelector(
        onTemplateSelected: _handleTemplateSelection,
      ),
    );
  }

  void _handleTemplateSelection(String templateContent) {
    _inputController.text = templateContent;
    setState(() {
      _showTemplates = false;
    });
  }

  void _stopStreaming() {
    setState(() {
      _isLoading = false;
      if (_messages.isNotEmpty && _messages.last.isStreaming) {
        final lastMessage = _messages.last;
        _messages[_messages.length - 1] = lastMessage.copyWith(
          isStreaming: false,
        );
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      HapticFeedback.lightImpact();
    }
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MessageBubble(
            message: message,
            modelName: ModelService.instance.selectedModel,
            onCopy: () => _copyMessage(message),
            onRegenerate: message.type == MessageType.assistant
                ? () => _regenerateMessage(index)
                : null,
            onExport: () => _exportMessage(message, index),
          ),
        );
      },
    );
  }

  Future<void> _handleSendMessage(String content, {bool useWebSearch = false}) async {
    final modelService = ModelService.instance;
    
    // Determine which models to use
    List<String> modelsToUse;
    if (modelService.multipleModelsEnabled && modelService.selectedModels.isNotEmpty) {
      modelsToUse = modelService.selectedModels;
    } else {
      modelsToUse = [modelService.selectedModel];
    }
    
    if (content.trim().isEmpty || modelsToUse.isEmpty || modelsToUse.first.isEmpty) return;

    final userMessage = Message.user(content.trim());
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    // Get conversation history (last 10 conversations = 20 messages)
    final allHistory = _messages
        .where((m) => !m.isStreaming && !m.hasError)
        .map((m) => m.toApiFormat())
        .toList();
    
    // Limit to last 20 messages (10 conversations) for memory efficiency
    final history = allHistory.length > 20 
        ? allHistory.sublist(allHistory.length - 20)
        : allHistory;

    // Remove the last user message from history to avoid duplication
    if (history.isNotEmpty && history.last['role'] == 'user') {
      history.removeLast();
    }

    try {
      // Handle web search if enabled
      String enhancedContent = content.trim();
      if (useWebSearch) {
        // Show searching indicator
        final searchingMessage = Message.assistant('🔍 Searching the web...', isStreaming: true);
        setState(() {
          _messages.add(searchingMessage);
        });
        
        // Perform web search
        final searchResults = await WebSearchService.search(query: content.trim());
        final searchData = WebSearchService.formatSearchResults(searchResults);
        final currentDateTime = WebSearchService.getCurrentDateTime();
        
        // Update content with search results and current time
        enhancedContent = '''$currentDateTime

Web Search Results for: "$content"

$searchData

Based on the above current information and search results, please provide a comprehensive response to: "$content"''';
        
        // Remove searching indicator
        setState(() {
          _messages.removeLast();
        });
      }
      
      // Handle multiple models or single model
      for (int i = 0; i < modelsToUse.length; i++) {
        final model = modelsToUse[i];
        
        // Create assistant message for each model
        final assistantMessage = Message.assistant('', isStreaming: true);
        setState(() {
          _messages.add(assistantMessage);
        });
        
        // Start response for this model
        _handleModelResponse(
          enhancedContent,
          model,
          history,
          _messages.length - 1,
          modelsToUse.length,
          i,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(Message.error(
            'Sorry, I encountered an error. Please try again.',
          ));
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleModelResponse(
    String content,
    String model,
    List<Map<String, String>> history,
    int messageIndex,
    int totalModels,
    int modelIndex,
  ) async {
    try {
      final stream = await ApiService.sendMessage(
        message: content,
        model: model,
        conversationHistory: history,
        systemPrompt: MessageModeService.instance.effectiveSystemPrompt,
      );

      String accumulatedContent = '';
      
      // Add model name header for multiple models
      if (totalModels > 1) {
        accumulatedContent = '**${_formatModelName(model)}:**\n\n';
      }
      
      int chunkCount = 0;
      await for (final chunk in stream) {
        if (!mounted) break;
        
        accumulatedContent += chunk;
        chunkCount++;
        
        if (messageIndex < _messages.length) {
          setState(() {
            _messages[messageIndex] = _messages[messageIndex].copyWith(
              content: accumulatedContent,
              isStreaming: true,
            );
          });
        }
        
        // Smooth auto-scroll during streaming
        if (chunkCount % 2 == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Only auto-scroll if user hasn't manually scrolled away
            if (_autoScrollEnabled && _scrollController.hasClients && !_userIsScrolling) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              final currentScroll = _scrollController.offset;
              
              // Smooth scroll to bottom if we're close (within 200 pixels)
              if (maxScroll - currentScroll < 200) {
                _scrollController.animateTo(
                  maxScroll,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.linear,
                );
              }
            }
          });
        }
      }

      // Mark streaming as complete
      if (mounted && messageIndex < _messages.length) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            content: accumulatedContent,
            isStreaming: false,
          );
          
          // Set loading to false when last model completes
          if (modelIndex == totalModels - 1) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted && messageIndex < _messages.length) {
        setState(() {
          _messages[messageIndex] = Message.error(
            'Error from ${_formatModelName(model)}: Please try again.',
          );
          
          if (modelIndex == totalModels - 1) {
            _isLoading = false;
          }
        });
      }
    }
  }

  String _formatModelName(String model) {
    return model
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Future<void> _regenerateMessage(int messageIndex) async {
    if (messageIndex <= 0 || messageIndex >= _messages.length) return;

    // Find the user message before this assistant message
    final userMessage = _messages[messageIndex - 1];
    if (userMessage.type != MessageType.user) return;

    // Remove the current assistant message
    setState(() {
      _messages.removeAt(messageIndex);
    });

    // Regenerate the response
    await _handleSendMessage(userMessage.content);
  }

  void _copyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 100,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportMessage(Message message, int index) async {
    // Find the corresponding user message for AI responses
    String userMessage = '';
    String aiResponse = message.content;
    
    if (message.type == MessageType.assistant && index > 0) {
      final previousMessage = _messages[index - 1];
      if (previousMessage.type == MessageType.user) {
        userMessage = previousMessage.content;
      }
    } else if (message.type == MessageType.user) {
      userMessage = message.content;
      // Find the next AI response
      if (index + 1 < _messages.length) {
        final nextMessage = _messages[index + 1];
        if (nextMessage.type == MessageType.assistant) {
          aiResponse = nextMessage.content;
        }
      }
    }
    
    // Handle different export types based on message type
    if (message is ImageMessage) {
      // Export image message
      await ExportService.exportGeneratedImage(
        context: context,
        imageUrl: message.imageUrl,
        prompt: message.prompt,
        model: message.model,
      );
    } else {
      // Export text message
      await ExportService.exportMessageAsImage(
        context: context,
        userMessage: userMessage,
        aiResponse: aiResponse,
        modelName: ModelService.instance.selectedModel,
      );
    }
  }

  Future<void> _handleVisionAnalysis(String prompt, String imageData) async {
    if (prompt.trim().isEmpty) return;
    
    final selectedModel = ModelService.instance.selectedModel;
    if (selectedModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a model first'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // For vision analysis, always get the best available vision model dynamically
    final bestVisionModel = await VisionService.getBestVisionModel();
    if (bestVisionModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No vision models available'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Add user message with image info
    final userMessage = VisionMessage.user(
      prompt: prompt,
      imageData: imageData,
      model: bestVisionModel,
    );
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Add AI response placeholder
      final aiMessage = Message.assistant('');
      setState(() {
        _messages.add(aiMessage);
      });

      final messageIndex = _messages.length - 1;

      // Get vision analysis stream
      final stream = await VisionService.analyzeImage(
        prompt: prompt,
        imageData: imageData,
        model: bestVisionModel,
      );

      String fullResponse = '';
      await for (final chunk in stream) {
        if (mounted) {
          fullResponse += chunk;
          setState(() {
            _messages[messageIndex] = Message.assistant(fullResponse);
          });
          _scrollToBottom();
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_messages.isNotEmpty && _messages.last.type == MessageType.assistant) {
            _messages[_messages.length - 1] = Message.assistant(
              'Sorry, I encountered an error while analyzing the image. Please try again.',
            );
          }
        });
      }
    }
  }

  Future<void> _handleImageGeneration(String prompt) async {
    final imageService = ImageService.instance;
    
    // Determine which image models to use
    List<String> modelsToUse;
    if (imageService.multipleModelsEnabled && imageService.selectedModels.isNotEmpty) {
      modelsToUse = imageService.selectedModels;
    } else {
      modelsToUse = [imageService.selectedModel];
    }
    
    if (prompt.trim().isEmpty || modelsToUse.isEmpty || modelsToUse.first.isEmpty) return;

    // Add user message
    final userMessage = Message.user('Generate image: $prompt');
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Handle multiple image models or single model
      for (int i = 0; i < modelsToUse.length; i++) {
        final model = modelsToUse[i];
        
        // Create image message for each model
        final imageMessage = ImageMessage.generating(prompt, model);
        setState(() {
          _messages.add(imageMessage);
        });
        
        // Start image generation for this model
        _handleImageModelResponse(
          prompt,
          model,
          _messages.length - 1,
          modelsToUse.length,
          i,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(Message.error(
            'Sorry, I encountered an error generating the image.',
          ));
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDiagramGeneration(String prompt) async {
    if (prompt.trim().isEmpty) return;
    
    final userMessage = Message.user('Create a diagram: $prompt');
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      // Reset auto-scroll for new message
      _autoScrollEnabled = true;
      _userIsScrolling = false;
    });
    
    _scrollToBottom();
    
    try {
      // Generate diagram using AI
      final diagramPrompt = '''Create a Mermaid diagram for: $prompt
      
Requirements:
1. Generate ONLY valid Mermaid code
2. Start directly with the diagram type (graph, flowchart, sequenceDiagram, etc.)
3. Do NOT include markdown code blocks or any explanations
4. Make it clear and well-structured
5. Use appropriate labels and connections

Example formats:
- Flowchart: graph TD or flowchart TD
- Sequence: sequenceDiagram
- Gantt: gantt
- Pie: pie title
- Class: classDiagram

Generate the Mermaid code now:''';
      
      final stream = await ApiService.sendMessage(
        message: diagramPrompt,
        model: ModelService.instance.selectedModel,
      );
      
      String mermaidCode = '';
      await for (final chunk in stream) {
        mermaidCode += chunk;
      }
      
      // Extract and clean the Mermaid code
      mermaidCode = DiagramService.extractMermaidCode(mermaidCode);
      
      // Fix common issues
      if (mermaidCode.isNotEmpty) {
        mermaidCode = DiagramService.fixCommonIssues(mermaidCode);
      }
      
      // Add diagram message
      final diagramMessage = DiagramMessage.assistant(
        prompt: prompt,
        mermaidCode: mermaidCode,
      );
      
      setState(() {
        _messages.add(diagramMessage);
        _isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(Message.error(
          'Sorry, I encountered an error generating the diagram. Please try again.',
        ));
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePresentationGeneration(String prompt) async {
    if (prompt.trim().isEmpty) return;

    final userMessage = Message.user('Create a presentation: $prompt');
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _autoScrollEnabled = true;
      _userIsScrolling = false;
    });

    _scrollToBottom();

    // Show loading dialog with countdown
    _showPresentationLoadingDialog(context);

    try {
      final presentationPrompt = '''Create a comprehensive professional presentation about: $prompt

Requirements:
1. Generate a well-structured presentation with as many slides as needed to cover the topic thoroughly
2. Each slide should have a clear title and content
3. Use bullet points where appropriate for better readability
4. Include speaker notes to provide additional context
5. Make it engaging, informative, and comprehensive
6. Cover all important aspects of the topic

Format the response as follows:
---SLIDE 1---
Title: [Slide Title]
Content: [Main content]
Bullets:
- Point 1
- Point 2
- Point 3
Notes: [Speaker notes]

---SLIDE 2---
[Continue same format for all slides]

Generate the complete presentation now:''';

      final stream = await ApiService.sendMessage(
        message: presentationPrompt,
        model: ModelService.instance.selectedModel,
      );

      String fullResponse = '';
      await for (final chunk in stream) {
        fullResponse += chunk;
      }

      // Parse the response into slides
      final slides = _parsePresentation(fullResponse);
      
      final presentationMessage = PresentationMessage.assistant(
        prompt: prompt,
        slides: slides,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      setState(() {
        _messages.add(presentationMessage);
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      setState(() {
        _messages.add(Message.error(
          'Sorry, I encountered an error generating the presentation. Please try again.',
        ));
        _isLoading = false;
      });
    }
  }

  void _showPresentationLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: _PresentationLoadingWidget(),
        );
      },
    );
  }

  List<PresentationSlide> _parsePresentation(String response) {
    final slides = <PresentationSlide>[];
    final slideRegex = RegExp(r'---SLIDE\s*\d+---', multiLine: true);
    final slideSections = response.split(slideRegex);
    
    for (final section in slideSections) {
      if (section.trim().isEmpty) continue;
      
      String title = '';
      String content = '';
      List<String> bullets = [];
      String notes = '';
      
      // Extract title
      final titleMatch = RegExp(r'Title:\s*(.+)').firstMatch(section);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.trim() ?? '';
      }
      
      // Extract content
      final contentMatch = RegExp(r'Content:\s*(.+?)(?=Bullets:|Notes:|$)', dotAll: true).firstMatch(section);
      if (contentMatch != null) {
        content = contentMatch.group(1)?.trim() ?? '';
      }
      
      // Extract bullets
      final bulletsMatch = RegExp(r'Bullets:\s*(.+?)(?=Notes:|$)', dotAll: true).firstMatch(section);
      if (bulletsMatch != null) {
        final bulletsText = bulletsMatch.group(1) ?? '';
        bullets = bulletsText
            .split('\n')
            .where((line) => line.trim().startsWith('-') || line.trim().startsWith('•'))
            .map((line) => line.replaceFirst(RegExp(r'^[-•]\s*'), '').trim())
            .where((line) => line.isNotEmpty)
            .toList();
      }
      
      // Extract notes
      final notesMatch = RegExp(r'Notes:\s*(.+)', dotAll: true).firstMatch(section);
      if (notesMatch != null) {
        notes = notesMatch.group(1)?.trim() ?? '';
      }
      
      if (title.isNotEmpty || content.isNotEmpty) {
        slides.add(PresentationSlide(
          title: title.isNotEmpty ? title : 'Slide ${slides.length + 1}',
          content: content,
          bulletPoints: bullets.isNotEmpty ? bullets : null,
          notes: notes.isNotEmpty ? notes : null,
        ));
      }
    }
    
    // If no slides were parsed, try alternative format
    if (slides.isEmpty) {
      // Try to create slides from paragraphs
      final paragraphs = response.split('\n\n');
      for (int i = 0; i < paragraphs.length && i < 10; i++) {
        final para = paragraphs[i].trim();
        if (para.isNotEmpty) {
          slides.add(PresentationSlide(
            title: 'Slide ${i + 1}',
            content: para,
          ));
        }
      }
    }
    
    return slides;
  }

  Future<void> _handleImageModelResponse(
    String prompt,
    String model,
    int messageIndex,
    int totalModels,
    int modelIndex,
  ) async {
    try {
      final imageUrl = await ImageService.generateImage(
        prompt: prompt,
        model: model,
      );

      if (mounted && messageIndex < _messages.length) {
        if (imageUrl != null) {
          // Success - update with completed image
          setState(() {
            _messages[messageIndex] = ImageMessage.completed(prompt, model, imageUrl);
            
            // Set loading to false when last model completes
            if (modelIndex == totalModels - 1) {
              _isLoading = false;
            }
          });
        } else {
          // Failed - show error
          setState(() {
            _messages[messageIndex] = ImageMessage.error(
              prompt, 
              model, 
              'Failed to generate image'
            );
            
            if (modelIndex == totalModels - 1) {
              _isLoading = false;
            }
          });
        }
      }
    } catch (e) {
      if (mounted && messageIndex < _messages.length) {
        setState(() {
          _messages[messageIndex] = ImageMessage.error(
            prompt,
            model,
            'Error: $e',
          );
          
          if (modelIndex == totalModels - 1) {
            _isLoading = false;
          }
        });
      }
    }
  }

  void _handleChartGeneration(String prompt) async {
    if (!mounted) return;
    
    // Add user message
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: prompt,
      type: MessageType.user,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
    });
    
    // Generate chart prompt
    final chartPrompt = '''
Generate a Chart.js configuration JSON for: $prompt

Requirements:
1. Return ONLY valid JSON configuration for Chart.js
2. Include appropriate chart type (bar, line, pie, doughnut, radar, scatter)
3. Use realistic sample data if not specified
4. Include proper labels, colors, and options
5. Make it visually appealing with good color schemes

Format the response as:
```json
{
  "type": "chart_type",
  "data": { ... },
  "options": { ... }
}
```
''';
    
    // Stream AI response
    String fullResponse = '';
    final assistantMessage = ChartMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_chart',
      prompt: prompt,
      chartConfig: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    
    setState(() {
      _messages.add(assistantMessage);
    });
    
    try {
      // Get the selected model
      final selectedModel = ModelService.instance.selectedModel;
      
      // Stream the response
      final stream = await ApiService.sendMessage(
        message: chartPrompt,
        model: selectedModel,
        conversationHistory: [],
        systemPrompt: MessageModeService.instance.effectiveSystemPrompt,
      );
      
      stream.listen(
        (chunk) {
          fullResponse += chunk;
          
          // Try to extract chart config as we stream
          final config = ChartService.extractChartConfig(fullResponse);
          if (config.isNotEmpty && mounted) {
            setState(() {
              final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
              if (index != -1) {
                _messages[index] = (assistantMessage as ChartMessage).copyWith(
                  chartConfig: config,
                  isStreaming: true,
                );
              }
            });
          }
        },
        onDone: () {
          if (mounted) {
            // Final extraction
            String finalConfig = ChartService.extractChartConfig(fullResponse);
            
            // If no valid config found, generate a sample
            if (finalConfig.isEmpty) {
              finalConfig = ChartService.generateSampleChart(prompt);
            }
            
            setState(() {
              final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
              if (index != -1) {
                _messages[index] = (assistantMessage as ChartMessage).copyWith(
                  chartConfig: finalConfig,
                  isStreaming: false,
                );
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            // Generate a sample chart on error
            final sampleConfig = ChartService.generateSampleChart(prompt);
            
            setState(() {
              final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
              if (index != -1) {
                _messages[index] = (assistantMessage as ChartMessage).copyWith(
                  chartConfig: sampleConfig,
                  isStreaming: false,
                  hasError: false, // Don't show error, just use sample
                );
              }
            });
          }
        },
      );
    } catch (e) {
      // Generate sample on exception
      final sampleConfig = ChartService.generateSampleChart(prompt);
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
          if (index != -1) {
            _messages[index] = (assistantMessage as ChartMessage).copyWith(
              chartConfig: sampleConfig,
              isStreaming: false,
            );
          }
        });
      }
    }
  }

  void _handleFlashcardGeneration(String prompt) async {
    if (!mounted) return;
    
    // Add user message
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: prompt,
      type: MessageType.user,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
    });
    
    // Generate flashcard prompt
    final flashcardPrompt = '''
Generate flashcards for: $prompt

Create educational flashcards with questions and answers.
Format as JSON array:
[
  {
    "question": "Question text",
    "answer": "Answer text",
    "explanation": "Optional explanation"
  }
]

Generate 5-10 flashcards covering key concepts.
''';
    
    // Stream AI response
    String fullResponse = '';
    final assistantMessage = FlashcardMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_flashcard',
      prompt: prompt,
      flashcards: [],
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    
    setState(() {
      _messages.add(assistantMessage);
    });
    
    try {
      final selectedModel = ModelService.instance.selectedModel;
      final stream = await ApiService.sendMessage(
        message: flashcardPrompt,
        model: selectedModel,
        conversationHistory: [],
        systemPrompt: MessageModeService.instance.effectiveSystemPrompt,
      );
      
      stream.listen(
        (chunk) {
          fullResponse += chunk;
          
          // Try to extract flashcards as we stream
          final flashcards = FlashcardService.extractFlashcards(fullResponse);
          if (flashcards.isNotEmpty && mounted) {
            setState(() {
              final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
              if (index != -1) {
                _messages[index] = (assistantMessage as FlashcardMessage).copyWith(
                  flashcards: flashcards,
                  isStreaming: true,
                );
              }
            });
          }
        },
        onDone: () {
          if (mounted) {
            // Final extraction
            List<FlashcardItem> finalFlashcards = FlashcardService.extractFlashcards(fullResponse);
            
            // If no flashcards found, generate samples
            if (finalFlashcards.isEmpty) {
              finalFlashcards = FlashcardService.generateSampleFlashcards(prompt);
            }
            
            setState(() {
              final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
              if (index != -1) {
                _messages[index] = (assistantMessage as FlashcardMessage).copyWith(
                  flashcards: finalFlashcards,
                  isStreaming: false,
                );
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            // Generate sample flashcards on error
            final sampleFlashcards = FlashcardService.generateSampleFlashcards(prompt);
            
            setState(() {
              final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
              if (index != -1) {
                _messages[index] = (assistantMessage as FlashcardMessage).copyWith(
                  flashcards: sampleFlashcards,
                  isStreaming: false,
                  hasError: false,
                );
              }
            });
          }
        },
      );
    } catch (e) {
      // Generate sample on exception
      final sampleFlashcards = FlashcardService.generateSampleFlashcards(prompt);
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
          if (index != -1) {
            _messages[index] = (assistantMessage as FlashcardMessage).copyWith(
              flashcards: sampleFlashcards,
              isStreaming: false,
            );
          }
        });
      }
    }
  }

  void _handleQuizGeneration(String prompt) async {
    if (!mounted) return;
    
    // Add user message
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: prompt,
      type: MessageType.user,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
    });
    
    // Generate quiz prompt
    final quizPrompt = '''
Generate a quiz for: $prompt

Create multiple-choice questions with 4 options each.
Format as JSON array:
[
  {
    "question": "Question text",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": 0,
    "explanation": "Why this answer is correct"
  }
]

Generate 5-10 questions. The correctAnswer is the index (0-3) of the correct option.
''';
    
    // Stream AI response
    String fullResponse = '';
    final assistantMessage = QuizMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_quiz',
      prompt: prompt,
      questions: [],
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    
    setState(() {
      _messages.add(assistantMessage);
    });
    
    try {
      final selectedModel = ModelService.instance.selectedModel;
      final stream = await ApiService.sendMessage(
        message: quizPrompt,
        model: selectedModel,
        conversationHistory: [],
        systemPrompt: MessageModeService.instance.effectiveSystemPrompt,
      );
      
      stream.listen(
        (chunk) {
          fullResponse += chunk;
          
          // Try to extract quiz questions as we stream
          final questions = QuizService.extractQuizQuestions(fullResponse);
          if (questions.isNotEmpty && mounted) {
            setState(() {
              final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
              if (index != -1) {
                _messages[index] = (assistantMessage as QuizMessage).copyWith(
                  questions: questions,
                  isStreaming: true,
                );
              }
            });
          }
        },
        onDone: () {
          if (mounted) {
            // Final extraction
            List<QuizQuestion> finalQuestions = QuizService.extractQuizQuestions(fullResponse);
            
            // If no questions found, generate samples
            if (finalQuestions.isEmpty) {
              finalQuestions = QuizService.generateSampleQuiz(prompt);
            }
            
            setState(() {
              final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
              if (index != -1) {
                _messages[index] = (assistantMessage as QuizMessage).copyWith(
                  questions: finalQuestions,
                  isStreaming: false,
                );
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            // Generate sample quiz on error
            final sampleQuestions = QuizService.generateSampleQuiz(prompt);
            
            setState(() {
              final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
              if (index != -1) {
                _messages[index] = (assistantMessage as QuizMessage).copyWith(
                  questions: sampleQuestions,
                  isStreaming: false,
                  hasError: false,
                );
              }
            });
          }
        },
      );
    } catch (e) {
      // Generate sample on exception
      final sampleQuestions = QuizService.generateSampleQuiz(prompt);
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
          if (index != -1) {
            _messages[index] = (assistantMessage as QuizMessage).copyWith(
              questions: sampleQuestions,
              isStreaming: false,
            );
          }
        });
      }
    }
  }

}

class _PresentationLoadingWidget extends StatefulWidget {
  @override
  _PresentationLoadingWidgetState createState() => _PresentationLoadingWidgetState();
}

class _PresentationLoadingWidgetState extends State<_PresentationLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseAnimation;
  int _secondsElapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    
    // Initialize shimmer animation
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    ));
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.slideshow_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Title
          Text(
            'Generating Presentation',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle with timer
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Creating your slides... ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                TextSpan(
                  text: _formatTime(_secondsElapsed),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Shimmer loading bars
          Column(
            children: List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 8,
                      width: 200 - (index * 30),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            theme.colorScheme.surfaceVariant,
                            theme.colorScheme.surfaceVariant,
                            theme.colorScheme.primary.withOpacity(0.3),
                            theme.colorScheme.surfaceVariant,
                            theme.colorScheme.surfaceVariant,
                          ],
                          stops: [
                            0.0,
                            _shimmerAnimation.value - 0.3,
                            _shimmerAnimation.value,
                            _shimmerAnimation.value + 0.3,
                            1.0,
                          ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
          
          const SizedBox(height: 16),
          
          // Tips text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI is crafting professional slides',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}