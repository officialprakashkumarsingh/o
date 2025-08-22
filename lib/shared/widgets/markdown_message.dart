import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/services/diagram_service.dart';
import 'diagram_preview.dart';

class MarkdownMessage extends StatelessWidget {
  final String content;
  final bool isUser;
  final bool isStreaming;

  const MarkdownMessage({
    super.key,
    required this.content,
    this.isUser = false,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      // User messages: simple text, no markdown
      return SelectableText(
        content,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
          height: 1.4,
        ),
      );
    }

    // Check if content contains Mermaid diagram
    if (_containsMermaidDiagram(content)) {
      return _buildContentWithDiagram(context);
    }

    // AI messages: full markdown support with custom code blocks
    final codeBlockBuilder = CodeBlockBuilder(context);
    
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: _buildMarkdownStyleSheet(context),
      builders: {
        'pre': codeBlockBuilder,
        'code': codeBlockBuilder,
      },
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      onTapLink: (text, href, title) {
        // Handle link taps if needed
      },
    );
  }

  bool _containsMermaidDiagram(String text) {
    return text.contains('```mermaid') || 
           text.contains('```Mermaid') || 
           text.contains('```MERMAID');
  }

  Widget _buildContentWithDiagram(BuildContext context) {
    // Split content by mermaid blocks
    final parts = <Widget>[];
    final regex = RegExp(r'```mermaid\s*([\s\S]*?)```', caseSensitive: false);
    int lastEnd = 0;
    
    for (final match in regex.allMatches(content)) {
      // Add text before diagram
      if (match.start > lastEnd) {
        final textBefore = content.substring(lastEnd, match.start);
        if (textBefore.trim().isNotEmpty) {
          final codeBlockBuilder = CodeBlockBuilder(context);
          parts.add(
            MarkdownBody(
              data: textBefore,
              selectable: true,
              styleSheet: _buildMarkdownStyleSheet(context),
              builders: {
                'pre': codeBlockBuilder,
                'code': codeBlockBuilder,
              },
              extensionSet: md.ExtensionSet(
                md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                [
                  md.EmojiSyntax(),
                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                ],
              ),
            ),
          );
        }
      }
      
      // Add diagram
      final mermaidCode = match.group(1)?.trim() ?? '';
      if (mermaidCode.isNotEmpty) {
        parts.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DiagramPreview(
              mermaidCode: mermaidCode,
            ),
          ),
        );
      }
      
      lastEnd = match.end;
    }
    
    // Add remaining text after last diagram
    if (lastEnd < content.length) {
      final textAfter = content.substring(lastEnd);
      if (textAfter.trim().isNotEmpty) {
        final codeBlockBuilder = CodeBlockBuilder(context);
        parts.add(
          MarkdownBody(
            data: textAfter,
            selectable: true,
            styleSheet: _buildMarkdownStyleSheet(context),
            builders: {
              'pre': codeBlockBuilder,
              'code': codeBlockBuilder,
            },
            extensionSet: md.ExtensionSet(
              md.ExtensionSet.gitHubFlavored.blockSyntaxes,
              [
                md.EmojiSyntax(),
                ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
              ],
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: parts,
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    
    return MarkdownStyleSheet(
      // Text styles
      p: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        height: 1.5,
      ),
      h1: theme.textTheme.headlineLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      h2: theme.textTheme.headlineMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      h3: theme.textTheme.headlineSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      h4: theme.textTheme.titleLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      h5: theme.textTheme.titleMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      h6: theme.textTheme.titleSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      
      // Code styles
      code: GoogleFonts.jetBrainsMono(
        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        color: textColor,
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      
      // List styles
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
      ),
      
      // Quote styles
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: textColor.withOpacity(0.8),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      
      // Link styles
      a: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      
      // Table styles
      tableHead: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      tableBody: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
      ),
      
      // Emphasis styles
      strong: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      em: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  
  CodeBlockBuilder(this.context);
  
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Handle pre blocks (code blocks)
    if (element.tag == 'pre') {
      String code = element.textContent;
      String language = '';
      
      // Try to extract language from code element inside pre
      for (final node in element.children ?? []) {
        if (node is md.Element && node.tag == 'code') {
          code = node.textContent;
          final className = node.attributes['class'] ?? '';
          if (className.startsWith('language-')) {
            language = className.substring('language-'.length);
          }
          break;
        }
      }
      
      // Return the custom code block widget
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: _CodeBlockWidget(
          code: code.trim(),
          language: language,
        ),
      );
    }
    
    // Handle inline code
    if (element.tag == 'code') {
      // Skip if this has a language class (it's part of a code block)
      final className = element.attributes['class'] ?? '';
      if (className.startsWith('language-')) {
        return null; // This will be handled by the pre block
      }
      
      // This is inline code
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          element.textContent,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
      );
    }
    
    return null;
  }
  
  String _extractLanguage(md.Element element) {
    final className = element.attributes['class'] ?? '';
    if (className.startsWith('language-')) {
      return className.substring('language-'.length);
    }
    // Also check for common language indicators
    final text = element.textContent.toLowerCase();
    if (text.contains('<!doctype html') || text.contains('<html')) {
      return 'html';
    }
    return '';
  }
}

class _CodeBlockWidget extends StatefulWidget {
  final String code;
  final String language;
  
  const _CodeBlockWidget({
    required this.code,
    required this.language,
  });
  
  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _copied = false;
  bool _showPreview = false;
  WebViewController? _webViewController;
  
  @override
  void initState() {
    super.initState();
    if (_isHtmlCode()) {
      _initWebView();
    }
  }
  
  bool _isHtmlCode() {
    return widget.language.toLowerCase() == 'html' || 
           widget.code.trim().toLowerCase().startsWith('<!doctype html') ||
           widget.code.trim().toLowerCase().startsWith('<html');
  }
  
  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadHtmlString(widget.code);
  }
  
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() {
      _copied = true;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Code copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
      ),
    );
  }
  
  void _togglePreview() {
    setState(() {
      _showPreview = !_showPreview;
      if (_showPreview && _webViewController == null) {
        _initWebView();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF282C34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Terminal header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFF21252B),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                // Terminal dots
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5F56),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFBD2E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF27C93F),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Language label
                if (widget.language.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.language,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                // HTML Preview button
                if (_isHtmlCode()) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _togglePreview,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Icon(
                              _showPreview ? Icons.code : Icons.preview,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showPreview ? 'Code' : 'Preview',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Copy button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _copyToClipboard,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Icon(
                            _copied ? Icons.check : Icons.content_copy,
                            size: 16,
                            color: _copied 
                                ? Colors.green 
                                : theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _copied ? 'Copied!' : 'Copy',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: _copied 
                                  ? Colors.green 
                                  : theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content or HTML preview
          if (_showPreview && _webViewController != null) ...[
            // HTML Preview
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: WebViewWidget(controller: _webViewController!),
            ),
          ] else ...[
            // Code content
            Container(
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(
                maxHeight: 400, // Limit height for very long code
              ),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: HighlightView(
                    widget.code,
                    language: widget.language.isEmpty ? 'plaintext' : widget.language,
                    theme: isDark ? monokaiSublimeTheme : atomOneLightTheme,
                    textStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}