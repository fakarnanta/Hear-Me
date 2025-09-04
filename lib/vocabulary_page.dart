import 'dart:convert';
import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hear_me/constant.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

class VocabularyPage extends StatefulWidget {
  final String sessionId;

  const VocabularyPage({Key? key, required this.sessionId}) : super(key: key);

  @override
  _VocabularyPageState createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  final TextEditingController _controller = TextEditingController();
  List<String> _vocabularyList = [];
  Map<String, List<String>> _allVocabularies = {};
  static const String _prefsKey = 'all_vocabularies';
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
  }

  Future<void> _loadVocabulary() async {
    final prefs = await SharedPreferences.getInstance();
    final String? vocabulariesJson = prefs.getString(_prefsKey);
    if (vocabulariesJson != null) {
      final Map<String, dynamic> decodedMap = json.decode(vocabulariesJson);
      setState(() {
        _allVocabularies =
            decodedMap.map((key, value) => MapEntry(key, List<String>.from(value)));
        _vocabularyList = _allVocabularies[widget.sessionId] ?? [];
      });
    }
  }

  Future<void> _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    _allVocabularies[widget.sessionId] = _vocabularyList;
    await prefs.setString(_prefsKey, json.encode(_allVocabularies));
  }

  void _addManualVocabulary() {
    if (_controller.text.trim().isEmpty) return;
    final words = _controller.text
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    _addVocabulary(words);
  }

  Future<void> _addVocabulary(List<String> words) async {
    bool added = false;
    final existingWords = _vocabularyList.toSet();
    for (final word in words) {
      if (existingWords.add(word)) {
        _vocabularyList.add(word);
        added = true;
      }
    }

    if (added) {
      setState(() {
        _controller.clear();
      });
      await _saveChanges();
    }
  }

  Future<void> _importFromFile() async {
    setState(() {
      _isImporting = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        String text = '';

        if (file.extension == 'pdf') {
          final PdfDocument document =
              PdfDocument(inputBytes: await File(file.path!).readAsBytes());
          text = PdfTextExtractor(document).extractText();
          document.dispose();
        }

        if (text.isNotEmpty) {
          final apiKey = dotenv.env['GEMINI_API_KEY'];
          if (apiKey == null) {
            throw Exception("GEMINI_API_KEY not found in .env file");
          }
          final model =
              GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: apiKey);
          final prompt =
              'You are an expert in linguistics and data extraction. Your task is to analyze the following text and extract a list of key vocabulary terms. The terms should be single words or short phrases (2-3 words) that are relevant to the main topics of the text. Exclude common words. The output must be a valid JSON array of strings. For example, for the text "The solar system consists of the Sun and the objects that orbit it.", a good output would be: ["solar system", "Sun", "orbit"]. Here is the text:\n---\n$text\n---';

          final content = [Content.text(prompt)];
          final response = await model.generateContent(content);

          if (response.text != null) {
            final jsonString = response.text!
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();
            final List<dynamic> extractedJson = json.decode(jsonString);
            final List<String> extractedWords =
                extractedJson.map((e) => e.toString()).toList();

            if (mounted) {
              await _showConfirmationDialog(extractedWords);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _showConfirmationDialog(List<String> words) async {
    final selectedWords = List<bool>.filled(words.length, true);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Confirm Vocabulary', style: GoogleFonts.plusJakartaSans()),
              content: SingleChildScrollView(
                child: ListBody(
                  children: List<Widget>.generate(words.length, (index) {
                    return CheckboxListTile(
                      title: Text(words[index], style: GoogleFonts.plusJakartaSans()),
                      value: selectedWords[index],
                      onChanged: (bool? value) {
                        setDialogState(() {
                          selectedWords[index] = value!;
                        });
                      },
                    );
                  }),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel', style: GoogleFonts.plusJakartaSans()),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Add', style: GoogleFonts.plusJakartaSans()),
                  onPressed: () {
                    final List<String> finalWords = [];
                    for (int i = 0; i < words.length; i++) {
                      if (selectedWords[i]) {
                        finalWords.add(words[i]);
                      }
                    }
                    _addVocabulary(finalWords);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submit() {
    if (mounted) {
      _addManualVocabulary();
      Navigator.pushNamed(context, '/stt-windows', arguments: widget.sessionId);
    }
  }

  Future<void> _removeVocabulary(String word) async {
    setState(() {
      _vocabularyList.remove(word);
    });
    await _saveChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                 
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 30,),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    width: 500,
                    margin: const EdgeInsets.symmetric(vertical: 20.0),
                    padding: const EdgeInsets.all(30.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Agar Column tidak memaksa mengisi semua ruang
                      children: [
                        Center(
                          child: Text(
                            'Tambahkan Kosakata',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Tambahkan kosakata agar transkrip lebih akurat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          )
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText:
                                  'Tambahkan manual contoh: makan, minum, belajar',
                              border: InputBorder.none,
                              hintStyle: GoogleFonts.plusJakartaSans(),
                            ),
                            style: GoogleFonts.plusJakartaSans(),
                            onSubmitted: (_) => _addManualVocabulary(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text('Ekstrak kosakata dari pdf',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _isImporting ? null : _importFromFile,
                          child: DottedBorder(
                              options: RoundedRectDottedBorderOptions(
                                         dashPattern: [10, 5],
                                          strokeWidth: 1,
                                          padding: EdgeInsets.all(16),
                                          radius: Radius.circular(12),
                                          color: Colors.grey.shade400,
                                        ),
                            child: Container(
                              height: 100,
                              width: double.infinity,
                              
                      
                              child: Center(
                                child: _isImporting
                                    ? const CircularProgressIndicator()
                                    : Text(
                                        'Berikan pdf materi',
                                        style: GoogleFonts.plusJakartaSans(
                                            color: Colors.grey.shade600),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text('List kosakata',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Container(
                          height: 150, // Memberi tinggi yang tetap pada container list
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _vocabularyList.isEmpty
                              ? Center(
                                  child: Text(
                                    'Kosakata yang ditambahkan akan muncul di sini.',
                                    style: GoogleFonts.plusJakartaSans(
                                        color: Colors.grey.shade600),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: _vocabularyList.map((word) {
                                      return Chip(
                                        label: Text(word, style: GoogleFonts.plusJakartaSans()),
                                        onDeleted: () => _removeVocabulary(word),
                                        deleteIcon: const Icon(Icons.close, size: 18),
                                        backgroundColor: Colors.blue.shade50,
                                        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.black),
                                        side: BorderSide(color: Colors.blue.shade100),
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text('Lanjutkan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}