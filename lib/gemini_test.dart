import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiClientScreen extends StatefulWidget {
  const GeminiClientScreen({super.key});

  @override
  State<GeminiClientScreen> createState() => _GeminiClientScreenState();
}

class _GeminiClientScreenState extends State<GeminiClientScreen> {
  final TextEditingController _promptController = TextEditingController();
  String _responseText = '';
  bool _isLoading = false;

  final String _apiKey = 'AIzaSyBX3bid20I18W9uLvomJXTnziFHQ1aRO4A'; // Ganti dengan API kamu

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _responseText = '';
    });

    final model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: _apiKey,
    );

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      setState(() {
        _responseText = response.text ?? "Tidak ada balasan dari Gemini.";
      });
    } catch (e) {
      setState(() {
        _responseText = "Terjadi kesalahan: $e";
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Client')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Masukkan prompt',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendPrompt,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Kirim ke Gemini"),
            ),
            const SizedBox(height: 20),
            const Text("🧠 Respons Gemini:"),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _responseText,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
