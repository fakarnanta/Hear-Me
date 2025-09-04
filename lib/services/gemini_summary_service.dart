
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiSummaryService {
  final GenerativeModel _model;

  GeminiSummaryService({required String apiKey}) :
      _model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: apiKey,
      );

  Future<String> generateSummary(Uint8List imageData, String transcript) async {
    try {
      final content = [
        Content.multi([
          TextPart('''Analyze the following whiteboard image and transcript. Your task is to:
                  1. Provide a concise, overarching summary of the main topic discussed.
                  2. Identify and list the key concepts or points from the transcript as bullet points.
                  3. For each key point, explicitly connect the information from the transcript to the specific visual elements in the whiteboard drawing.
                  4. Use Markdown for formatting, including headers, bold text, and bullet points.
                  5. If mathematical formulas are present, format them using LaTeX delimiters.
                  Ensure the summary is clear, structured, and easy to understand.
                  6. Avoid including any irrelevant details or personal opinions.
                  8. Berikan output dalam bahasa Indonesia.
                  9. Jangan sebutkan secara eksplisit hubungan transkrip dan papan tulis.
                  10. Jangan sebutkan transkrip secara eksplisit, gunakan kata sesi ini sebagai kata ganti.
                  '''),
          DataPart('image/png', imageData),
          TextPart(transcript),
        ])
      ];

      final response = await _model.generateContent(content);
      return response.text ?? 'No summary generated.';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
