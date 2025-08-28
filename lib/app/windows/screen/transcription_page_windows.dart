import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/services/livestream_service.dart';
import 'package:line_icons/line_icon.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:hear_me/services/azure_stt_bridge.dart';
import 'package:provider/provider.dart';

import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:hear_me/services/gemini_summary_service.dart';
import 'package:hear_me/app/windows/screen/summary_page.dart';

import 'package:hear_me/services/whiteboard_stream_service.dart';

// --- Widget Utama ---
class TranscriptionPageWindows extends StatefulWidget {
  const TranscriptionPageWindows({super.key});

  @override
  State<TranscriptionPageWindows> createState() =>
      _TranscriptionPageWindowsState();
}

class _TranscriptionPageWindowsState extends State<TranscriptionPageWindows> {
  // --- State ---
  late final AzureSttBridgeService _sttBridge;
  late final LivestreamService _livestreamService;
  StreamSubscription? _bridgeSubscription;
  bool _isBridgeInitialized = false;
  final GlobalKey _whiteboardKey = GlobalKey();
  final GeminiSummaryService _geminiSummaryService = GeminiSummaryService();

  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<bool> _isTranscriptMinimizedNotifier =
      ValueNotifier<bool>(false);

  // --- Whiteboard features state ---
  final ValueNotifier<Color> _selectedColorNotifier =
      ValueNotifier<Color>(Colors.black);
  final ValueNotifier<bool> _isErasingNotifier = ValueNotifier<bool>(false);
  double _strokeWidth = 4.0;
  final TransformationController _transformationController =
      TransformationController();
  int _pointerCount = 0;
  final ValueNotifier<bool> _isDrawingModeNotifier = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _sttBridge = context.read<AzureSttBridgeService>();
    _livestreamService = context.read<LivestreamService>();
    _initializeBridge();
    _requestMicrophonePermission();
    _listenToBridge();
  }

  Future<void> _initializeBridge() async {
    try {
      await _sttBridge.startBridgeExe();
      if (mounted) {
        setState(() {
          _isBridgeInitialized = true;
        });
        _livestreamService
            .addTranscript('Tekan tombol mikrofon untuk mulai berbicara...');
      }
    } catch (e) {
      if (mounted) {
        _livestreamService.addTranscript('Error initializing bridge: $e');
      }
    }
  }

  @override
  void dispose() {
    _bridgeSubscription?.cancel();
    if (_livestreamService.isListeningNotifier.value) {
      _sttBridge.stopListening();
    }
    _scrollController.dispose();
    _transformationController.dispose();
    _selectedColorNotifier.dispose();
    _isErasingNotifier.dispose();
    _isDrawingModeNotifier.dispose();
    _isTranscriptMinimizedNotifier.dispose();
    super.dispose();
  }

  Future<void> _requestMicrophonePermission() async {
    await Permission.microphone.request();
  }

// Di dalam file transcription_page_windows.dart

  void _listenToBridge() {
    _bridgeSubscription = _sttBridge.stream.listen((event) {
      // Cek dulu apakah 'type' ada di dalam event
      if (event['type'] == null) return;

      final type = event['type'] as String;

      // --- PERBAIKAN DI SINI ---
      // GANTI: if (type == 'partial' || type == 'final')
      // MENJADI: if (type == 'transcription')
      if (type == 'transcription') {
        // Pastikan payload dan text tidak null untuk menghindari error
        final payload = event['payload'] as Map<String, dynamic>?;
        if (payload != null && payload['text'] != null) {
          final transcript = payload['text'] as String;

          _livestreamService.addTranscript(transcript);
        }

        // Sisa kode (untuk 'error' dan 'info') sudah benar, tidak perlu diubah.
      } else if (type == 'error') {
        // ... (tanpa perubahan)
      } else if (type == 'info') {
        // ... (tanpa perubahan)
      }
    });
  }

// Di dalam file transcription_page_windows.dart

  Future<void> _toggleListening() async {
    if (!_isBridgeInitialized) return;

    if (_livestreamService.isListeningNotifier.value) {
      await _sttBridge.stopListening();
      _livestreamService.stopListening();
    } else {
      var status = await Permission.microphone.status;
      if (status.isGranted) {
        try {
          print("Mencoba memulai listening..."); // Tambahkan log untuk debug
          await _sttBridge.startListening();
          _livestreamService.startListening();
          print("Start listening berhasil dipanggil.");
        } catch (e) {
          print("Error saat startListening: $e"); // Cetak error ke console
          // Tampilkan pesan error di UI agar pengguna tahu
          _livestreamService.addTranscript('Error memulai mikrofon: $e');
        }
        // -----------------------------------------
      } else {
        // Logika jika izin ditolak sudah benar
        _livestreamService.addTranscript('Izin mikrofon ditolak.');
      }
    }
  }

  void _onPointerDown(PointerDownEvent details) {
    if (!_isDrawingModeNotifier.value) return;
    _pointerCount++;
    if (_pointerCount == 1) {
      final Matrix4 inverse = Matrix4.inverted(_transformationController.value);
      final vector.Vector3 transformedPosition = inverse.perspectiveTransform(
          vector.Vector3(
              details.localPosition.dx, details.localPosition.dy, 0));
      final offset = Offset(transformedPosition.x, transformedPosition.y);

      _livestreamService.onPointerDown(offset, _selectedColorNotifier.value,
          _strokeWidth, _isErasingNotifier.value);
    }
  }

  void _onPointerMove(PointerMoveEvent details) {
    if (!_isDrawingModeNotifier.value) return;
    if (_pointerCount == 1) {
      final Matrix4 inverse = Matrix4.inverted(_transformationController.value);
      final vector.Vector3 transformedPosition = inverse.perspectiveTransform(
          vector.Vector3(
              details.localPosition.dx, details.localPosition.dy, 0));
      final offset = Offset(transformedPosition.x, transformedPosition.y);

      _livestreamService.onPointerMove(offset);
    }
  }

  void _onPointerUp(PointerUpEvent details) {
    if (!_isDrawingModeNotifier.value) return;
    _pointerCount--;
    if (_pointerCount == 0) {
      _livestreamService.onPointerUp();
    }
  }

  void _clearCanvas() {
    _livestreamService.clear();
  }

  void _undo() {
    _livestreamService.undo();
  }

  void _toggleEraser() {
    _isErasingNotifier.value = !_isErasingNotifier.value;
  }

  void _selectColor(Color color) {
    _selectedColorNotifier.value = color;
    _isErasingNotifier.value = false;
  }

  void _toggleMode() {
    _isDrawingModeNotifier.value = !_isDrawingModeNotifier.value;
  }

  void _toggleTranscriptView() => _isTranscriptMinimizedNotifier.value =
      !_isTranscriptMinimizedNotifier.value;

  Future<void> _generateSummary() async {
    await Future.delayed(Duration.zero);
    // Tampilkan dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // --- PERBAIKAN 1: Pemeriksaan Konteks Widget yang Aman ---
      final boundaryContext = _whiteboardKey.currentContext;
      if (boundaryContext == null) {
        // Jika konteks tidak ditemukan, lempar error yang jelas
        throw Exception(
            "Gagal menemukan konteks whiteboard. Pastikan whiteboard terlihat di layar.");
      }
      final boundary =
          boundaryContext.findRenderObject() as RenderRepaintBoundary;
      // --------------------------------------------------------

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      // --- PERBAIKAN 2: Pemeriksaan Data Byte yang Aman ---
      if (byteData == null) {
        // Jika konversi gambar gagal, lempar error yang jelas
        throw Exception("Gagal mengubah gambar menjadi data byte.");
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      // ----------------------------------------------------

      final String transcript =
          _livestreamService.transcriptsStream.value.join('\n\n');

      final String summary =
          await _geminiSummaryService.generateSummary(pngBytes, transcript);

      _livestreamService.sendSummary(summary);

      // Tutup dialog loading SEBELUM navigasi
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SummaryPage(summaryText: summary),
          ),
        );
      }
    } catch (e) {
      // Tutup dialog loading dan tampilkan pesan error yang lebih informatif
      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildWhiteboardPanel(),
          _buildSessionHeader(),
               
          FloatingTranscriptPanel(
                  livestreamService: _livestreamService,
                  isTranscriptMinimizedNotifier: _isTranscriptMinimizedNotifier,
                  isBridgeInitialized: _isBridgeInitialized,
                  toggleListening: _toggleListening,
                  toggleTranscriptView: _toggleTranscriptView,
                  scrollController: _scrollController,
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Positioned(
      top: 110,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            )
          ],
        ),
        child: Column(
          children: [
            IconButton(
              icon: Icon(Icons.undo),
              onPressed: _undo,
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _clearCanvas,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isErasingNotifier,
              builder: (context, isErasing, child) {
                return IconButton(
                  icon: Icon(Icons.edit),
                  color: isErasing ? Colors.blue : Colors.black,
                  onPressed: _toggleEraser,
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isDrawingModeNotifier,
              builder: (context, isDrawingMode, child) {
                return IconButton(
                  icon: Icon(isDrawingMode ? Icons.pan_tool : Icons.edit),
                  onPressed: _toggleMode,
                );
              },
            ),
            SizedBox(height: 10),
            IconButton(
              icon: Icon(Icons.summarize),
              onPressed: _generateSummary,
            ),
            _buildColorPalette(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return ValueListenableBuilder<Color>(
      valueListenable: _selectedColorNotifier,
      builder: (context, selectedColor, child) {
        return Column(
          children: [
            GestureDetector(
              onTap: () => _selectColor(Colors.black),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: selectedColor == Colors.black
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
              ),
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () => _selectColor(Colors.red),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: selectedColor == Colors.red
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
              ),
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () => _selectColor(Colors.green),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: selectedColor == Colors.green
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
              ),
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () => _selectColor(Colors.blue),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: selectedColor == Colors.blue
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSessionHeader() {
  // BENAR: Widget terluarnya adalah Positioned
  return Positioned(
    top: 37,
    left: 24,
    child: Container( // Container sekarang ada di dalam Positioned
      width:  MediaQuery.of(context).size.width * 0.3,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        // ... isi header (tombol panah, teks, dll)
        children: [
          IconButton(
              onPressed: () => Navigator.of(context).pop(), // Aksi kembali
              icon: LineIcon.arrowLeft(),
              color: Colors.white),
          const SizedBox(width: 5),
          Text(
            'Judul Sesi',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
// Di dalam file transcription_page_windows.dart

  Widget _buildWhiteboardPanel() {
    // Di dalam metode build dari widget whiteboard Anda
    return RepaintBoundary(
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        // BUNGKUS InteractiveViewer dengan ValueListenableBuilder
        child: ValueListenableBuilder<bool>(
          valueListenable: _isDrawingModeNotifier,
          builder: (context, isDrawingMode, child) {
            // 'isDrawingMode' adalah nilai terbaru dari notifier
            return InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.1,
              maxScale: 4.0,
              // Gunakan nilai terbaru untuk mengontrol pan & zoom
              panEnabled: !isDrawingMode,
              scaleEnabled: !isDrawingMode,
              clipBehavior: Clip.none,
              // 'child' dari builder ini akan diteruskan ke sini
              child: child!,
            );
          },
          // LETAKKAN StreamBuilder sebagai 'child' agar tidak ikut di-rebuild
          // oleh ValueListenableBuilder. Ini adalah optimasi penting!
          child: StreamBuilder<List<DrawingPath>>(
            stream: _livestreamService.pathsStream,
            builder: (context, snapshot) {
              final paths = snapshot.data ?? [];
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: DrawingPainter(paths: paths),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingTranscriptPanel() {
    const primaryColor = Color(0xFF4A657D);

    return Positioned(
    top: 110, 
    left: 20,
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isTranscriptMinimizedNotifier,
          builder: (context, isTranscriptMinimized, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: MediaQuery.of(context).size.width * 0.3,
              height: isTranscriptMinimized ? 90 : 400,
              padding: const EdgeInsets.only(
                  left: 25, right: 25, top: 20, bottom: 30),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Transkrip',
                            style: GoogleFonts.plusJakartaSans(
                                color: primaryColor,
                                fontWeight: FontWeight.w600)),
                      ),
                      Row(
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                _livestreamService.isListeningNotifier,
                            builder: (context, isListening, child) {
                              return IconButton(
                                icon: Icon(
                                    isListening ? Icons.mic : Icons.mic_off,
                                    color: Colors.white70),
                                onPressed: _isBridgeInitialized
                                    ? _toggleListening
                                    : null,
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(
                                isTranscriptMinimized
                                    ? Icons.open_in_full
                                    : Icons.close_fullscreen,
                                color: Colors.white70),
                            onPressed: _toggleTranscriptView,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!isTranscriptMinimized) ...[
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white30),
                    Expanded(
                      child: StreamBuilder<List<String>>(
                        stream: _livestreamService.transcriptsStream,
                        builder: (context, snapshot) {
                          final transcripts = snapshot.data ?? [];
                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: transcripts.length,
                            itemBuilder: (context, index) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8.0, top: 4.0),
                              child: Text(
                                transcripts[index],
                                style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ]
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Ganti seluruh metode _buildFloatingTranscriptPanel() Anda dengan pemanggilan widget baru ini.

// 1. Widget Utama (Stateful/Stateless Sesuai Kebutuhan Induknya)
class FloatingTranscriptPanel extends StatelessWidget {
  const FloatingTranscriptPanel({
    super.key,
    required this.livestreamService,
    required this.isTranscriptMinimizedNotifier,
    required this.isBridgeInitialized,
    required this.toggleListening,
    required this.toggleTranscriptView,
    required this.scrollController,
  });

  final LivestreamService livestreamService;
  final ValueNotifier<bool> isTranscriptMinimizedNotifier;
  final bool isBridgeInitialized;
  final VoidCallback toggleListening;
  final VoidCallback toggleTranscriptView;
  final ScrollController scrollController;

  static const primaryColor = Color(0xFF4A657D);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 110,
      left: 20,
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ValueListenableBuilder<bool>(
          valueListenable: isTranscriptMinimizedNotifier,
          builder: (context, isMinimized, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: MediaQuery.of(context).size.width * 0.3,
              height: isMinimized ? 90 : 400,
              padding: const EdgeInsets.only(
                  left: 25, right: 25, top: 20, bottom: 30),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // WIDGET HEADER (TIDAK AKAN REBUILD SAAT TRANSKRIP UPDATE)
                  _TranscriptHeader(
                    isListeningNotifier: livestreamService.isListeningNotifier,
                    isBridgeInitialized: isBridgeInitialized,
                    onToggleListening: toggleListening,
                    onToggleView: toggleTranscriptView,
                    isMinimized: isMinimized,
                    primaryColor: primaryColor,
                  ),
                  // HANYA TAMPILKAN DAFTAR JIKA TIDAK DIMINIMIZE
                  if (!isMinimized) ...[
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white30),
                    // WIDGET DAFTAR TRANSKRIP (HANYA INI YANG AKAN REBUILD)
                    _TranscriptList(
                      transcriptsStream: livestreamService.transcriptsStream,
                      scrollController: scrollController,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// 2. Widget untuk Header Panel (Statis)
class _TranscriptHeader extends StatelessWidget {
  const _TranscriptHeader({
    required this.isListeningNotifier,
    required this.isBridgeInitialized,
    required this.onToggleListening,
    required this.onToggleView,
    required this.isMinimized,
    required this.primaryColor,
  });

  final ValueNotifier<bool> isListeningNotifier;
  final bool isBridgeInitialized;
  final VoidCallback onToggleListening;
  final VoidCallback onToggleView;
  final bool isMinimized;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD9D9D9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Transkrip',
            style: GoogleFonts.plusJakartaSans(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Row(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: isListeningNotifier,
              builder: (context, isListening, _) {
                return IconButton(
                  icon: Icon(isListening ? Icons.mic : Icons.mic_off,
                      color: Colors.white70),
                  onPressed: isBridgeInitialized ? onToggleListening : null,
                );
              },
            ),
            IconButton(
              icon: Icon(
                isMinimized ? Icons.open_in_full : Icons.close_fullscreen,
                color: Colors.white70,
              ),
              onPressed: onToggleView,
            ),
          ],
        ),
      ],
    );
  }
}

// 3. Widget untuk Daftar Transkrip (Dinamis dan Terisolasi)
class _TranscriptList extends StatelessWidget {
  const _TranscriptList({
    required this.transcriptsStream,
    required this.scrollController,
  });

  final Stream<List<String>> transcriptsStream;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<List<String>>(
        stream: transcriptsStream,
        builder: (context, snapshot) {
          final transcripts = snapshot.data ?? [];
          // Auto-scroll ke bawah saat ada transkrip baru
          if (scrollController.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            });
          }
          return ListView.builder(
            controller: scrollController,
            itemCount: transcripts.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
              child: Text(
                transcripts[index],
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
