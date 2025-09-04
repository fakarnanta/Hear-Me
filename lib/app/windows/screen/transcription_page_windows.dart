import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/app/windows/screen/summary_page.dart';
import 'package:hear_me/services/azure_stt_bridge.dart';
import 'package:hear_me/services/gemini_summary_service.dart';
import 'package:hear_me/services/livestream_service.dart';
import 'package:hear_me/services/whiteboard_stream_service.dart';
import 'package:line_icons/line_icon.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/streams.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:hear_me/constant.dart';

class TranscriptionPageWindows extends StatefulWidget {
  final String? sessionId;

  const TranscriptionPageWindows({super.key, this.sessionId});

  @override
  State<TranscriptionPageWindows> createState() =>
      _TranscriptionPageWindowsState();
}

class _TranscriptionPageWindowsState extends State<TranscriptionPageWindows> {
  // --- Services & Controllers ---
  late final AzureSttBridgeService _sttBridge;
  late final LivestreamService _livestreamService;
  final GeminiSummaryService _geminiSummaryService = GeminiSummaryService(apiKey: dotenv.env['GEMINI_API_KEY']!);

  StreamSubscription? _bridgeSubscription;
  final ScrollController _scrollController = ScrollController();
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _whiteboardKey = GlobalKey();


  bool _isBridgeInitialized = false;
  final ValueNotifier<bool> _isTranscriptMinimizedNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<Color> _selectedColorNotifier =
      ValueNotifier<Color>(Colors.black);
  final ValueNotifier<bool> _isErasingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isDrawingModeNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isHandRaised = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _raisedHandUser = ValueNotifier<String?>(null);

  // --- Drawing State ---
  final double _strokeWidth = 4.0;
  int _pointerCount = 0;

  @override
  void initState() {
    super.initState();
    _sttBridge = context.read<AzureSttBridgeService>();
    _livestreamService = context.read<LivestreamService>();
    _livestreamService.currentSessionId = widget.sessionId;
    _initializeBridge();
    _requestMicrophonePermission();
    _listenToBridge();
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
    _isHandRaised.dispose();
    super.dispose();
  }

  Future<void> _initializeBridge() async {
    try {
      await _sttBridge.startBridgeExe();
      if (mounted) {
        setState(() {
          _isBridgeInitialized = true;
        });
        _addSystemMessage('Tekan tombol mikrofon untuk mulai berbicara...');
      }
    } catch (e) {
      if (mounted) {
        _addSystemMessage('Error initializing bridge: $e');
      }
    }
  }

  Future<void> _requestMicrophonePermission() async {
    await Permission.microphone.request();
  }

  void _listenToBridge() {
    _livestreamService.handRaiseStream.listen((userName) {
      _raisedHandUser.value = userName;
      // Hide the indicator after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _raisedHandUser.value = null;
        }
      });
    });

    _bridgeSubscription = _sttBridge.stream.listen((event) {
      _livestreamService.handleBridgeMessage(event);
    });
  }

  Future<void> _toggleListening() async {
    if (!_isBridgeInitialized) return;

    final isCurrentlyListening = _livestreamService.isListeningNotifier.value;

    try {
      if (isCurrentlyListening) {
        
        await _sttBridge.stopListening();
      } else {
        var status = await Permission.microphone.status;
        if (status.isGranted) {
          await _sttBridge.startListening();
        } else {
          _addSystemMessage('Izin mikrofon ditolak.');
        }
      }
    } catch (e) {
      _addSystemMessage('Error: $e');
    }
  }
  
  void _addSystemMessage(String text) {
    final entry = TranscriptEntry(speakerId: "System", text: text, color: Colors.grey);
    _livestreamService.addTranscript(entry);
  }

  // --- Drawing and Whiteboard Methods ---

  void _onPointerDown(PointerDownEvent details) {
    if (!_isDrawingModeNotifier.value) return;
    _pointerCount++;
    if (_pointerCount == 1) {
      final Matrix4 inverse = Matrix4.inverted(_transformationController.value);
      final vector.Vector3 transformedPosition = inverse.perspectiveTransform(
          vector.Vector3(details.localPosition.dx, details.localPosition.dy, 0));
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
          vector.Vector3(details.localPosition.dx, details.localPosition.dy, 0));
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

  void _clearCanvas() => _livestreamService.clear();
  void _undo() => _livestreamService.undo();
  void _toggleEraser() => _isErasingNotifier.value = !_isErasingNotifier.value;
  void _selectColor(Color color) {
    _selectedColorNotifier.value = color;
    _isErasingNotifier.value = false;
  }

  void _toggleMode() =>
      _isDrawingModeNotifier.value = !_isDrawingModeNotifier.value;

  void _toggleTranscriptView() =>
      _isTranscriptMinimizedNotifier.value = !_isTranscriptMinimizedNotifier.value;

  Future<void> _generateSummary() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final boundaryContext = _whiteboardKey.currentContext;
      if (boundaryContext == null) {
        throw Exception("Whiteboard context not found.");
      }
      final boundary =
          boundaryContext.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception("Failed to convert image to byte data.");
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final String transcript =
          _livestreamService.transcriptsStream.value.map((e) => e.text).join('\n\n');

      final String summary =
          await _geminiSummaryService.generateSummary(pngBytes, transcript);

      _livestreamService.sendSummary(summary);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SummaryPage(summaryText: summary),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog on error
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating summary: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center, // Align stack children
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
          // Hand Raise Indicator
          ValueListenableBuilder<String?>(
            valueListenable: _raisedHandUser,
            builder: (context, userName, child) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                bottom: 20,
                right: userName == null ? -300 : 20, 
                child: AnimatedOpacity(
                  opacity: userName == null ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.front_hand, color: Colors.white, size: 30),
                        const SizedBox(width: 10),
                        Text(
                          '${userName?.split(' ').first ?? 'User'} sedang mengangkat tangan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
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
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            IconButton(icon: const Icon(Icons.undo), onPressed: _undo),
            IconButton(icon: const Icon(Icons.delete), onPressed: _clearCanvas),
            ValueListenableBuilder<bool>(
              valueListenable: _isErasingNotifier,
              builder: (context, isErasing, child) {
                return IconButton(
                  icon: const Icon(Icons.edit),
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
            const SizedBox(height: 10),
            IconButton(
              icon: const Icon(Icons.summarize),
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
            _ColorButton(color: Colors.black, selectedColor: selectedColor, onSelect: _selectColor),
            const SizedBox(height: 10),
            _ColorButton(color: Colors.red, selectedColor: selectedColor, onSelect: _selectColor),
            const SizedBox(height: 10),
            _ColorButton(color: Colors.green, selectedColor: selectedColor, onSelect: _selectColor),
            const SizedBox(height: 10),
            _ColorButton(color: Colors.blue, selectedColor: selectedColor, onSelect: _selectColor),
          ],
        );
      },
    );
  }

  Widget _buildSessionHeader() {
    return Positioned(
      top: 37,
      left: 24,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: LineIcon.arrowLeft(),
                color: Colors.white),
            const SizedBox(width: 5),
            Text(
              widget.sessionId ?? 'Judul Sesi',
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

  Widget _buildWhiteboardPanel() {
    return RepaintBoundary(
      key: _whiteboardKey,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isDrawingModeNotifier,
          builder: (context, isDrawingMode, child) {
            return InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.1,
              maxScale: 4.0,
              panEnabled: !isDrawingMode,
              scaleEnabled: !isDrawingMode,
              clipBehavior: Clip.none,
              child: child!,
            );
          },
          child: StreamBuilder<List<DrawingPath>>(
            stream: _livestreamService.pathsStream,
            builder: (context, snapshot) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: DrawingPainter(paths: snapshot.data ?? []),
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- Helper Widgets for UI Composition ---

class _ColorButton extends StatelessWidget {
  final Color color;
  final Color selectedColor;
  final ValueChanged<Color> onSelect;

  const _ColorButton({
    required this.color,
    required this.selectedColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelect(color),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: color == selectedColor
              ? Border.all(color: Colors.blue, width: 2)
              : null,
        ),
      ),
    );
  }
}

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
                  _TranscriptHeader(
                    isListeningNotifier: livestreamService.isListeningNotifier,
                    isBridgeInitialized: isBridgeInitialized,
                    onToggleListening: toggleListening,
                    onToggleView: toggleTranscriptView,
                    isMinimized: isMinimized,
                    primaryColor: primaryColor,
                  ),
                  if (!isMinimized) ...[
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white30),
                    _TranscriptList(
                      livestreamService: livestreamService,
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


class _TranscriptList extends StatelessWidget {
  const _TranscriptList({
    required this.livestreamService,
    required this.scrollController,
  });

  final LivestreamService livestreamService;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      // 1. Menggunakan CombineLatestStream untuk mendengarkan dua stream sekaligus
      child: StreamBuilder<({List<TranscriptEntry> transcripts, TranscriptEntry? partial})>(
        stream: CombineLatestStream.combine2(
            livestreamService.transcriptsStream,       // Stream transkrip final
            livestreamService.partialTranscriptStream, // Stream transkrip parsial
            (transcripts, partial) => (transcripts: transcripts, partial: partial)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          final finalTranscripts = snapshot.data!.transcripts;
          final partialEntry = snapshot.data!.partial;

          // 2. Menggabungkan daftar transkrip final dengan entri parsial (jika ada)
          final allItems = [...finalTranscripts];
          if (partialEntry != null && partialEntry.text.isNotEmpty) {
            allItems.add(partialEntry);
          }

          // Logika untuk auto-scroll ke bawah saat ada konten baru
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollController.hasClients && scrollController.position.maxScrollExtent > 0) {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          });

          return ListView.builder(
            controller: scrollController,
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final entry = allItems[index];
              // 3. Mengecek apakah item ini adalah entri parsial yang sedang berjalan
              final isPartial = (partialEntry != null && partialEntry.text.isNotEmpty) && (index == allItems.length - 1);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                // 4. Menggunakan Text.rich untuk styling yang kompleks
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: "${entry.speakerId}: ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPartial ? entry.color.withOpacity(0.7) : entry.color,
                          // Memberikan highlight jika ini adalah transkrip parsial
                          backgroundColor: isPartial ? Colors.white.withOpacity(0.2) : Colors.transparent,
                        ),
                      ),
                      TextSpan(
                        text: entry.text,
                        style: TextStyle(
                          color: isPartial ? Colors.white.withOpacity(0.7) : Colors.white,
                          // Memberikan highlight jika ini adalah transkrip parsial
                          backgroundColor: isPartial ? Colors.white.withOpacity(0.2) : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}