import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  static Future<String> extractTextFromPdf(File pdfFile) async {
    try {
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: await pdfFile.readAsBytes());
      
      // Extract text from all pages
      String extractedText = '';
      
      for (int i = 0; i < document.pages.count; i++) {
        // Extract text from the page
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        
        if (pageText.isNotEmpty) {
          extractedText += 'Page ${i + 1}:\n$pageText\n\n';
        }
      }
      
      // Dispose the document
      document.dispose();
      
      if (extractedText.isEmpty) {
        return 'Could not extract text from the PDF. The file might be image-based or empty.';
      }
      
      return extractedText.trim();
    } catch (e) {
      print('Error extracting text from PDF: $e');
      return 'Error reading PDF file: ${e.toString()}';
    }
  }
  
  static String formatPdfContent(String fileName, String extractedText) {
    return '''
PDF File: $fileName

Content:
$extractedText

Please analyze and respond based on the above PDF content.
''';
  }
}