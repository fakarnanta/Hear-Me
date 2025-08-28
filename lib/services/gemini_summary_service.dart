
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiSummaryService {
  final GenerativeModel _model;

  GeminiSummaryService() :
      _model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
      );

  Future<String> generateSummary(Uint8List imageData, String transcript) async {
    try {
      final content = [
        Content.multi([
          TextPart('Analyze the following whiteboard image and transcript. Provide a summary of the key points from the transcript and relate them to the different parts of the drawing. Format the output nicely using markdown.'),
          DataPart('image/png', imageData),
          TextPart(transcript),
        ])
      ];

      final response = await _model.generateContent(content);
      return response.text ?? 'No summary generated.';
    } catch (e) {
      return 'Error generating summary: $e';
    }
  }
}
