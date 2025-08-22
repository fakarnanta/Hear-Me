import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icon.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:hear_me/services/azure_stt_bridge.dart';
import 'package:provider/provider.dart';

class DrawingPath {
  Path path;
  Paint paint;
  DrawingPath({required this.path, required this.paint});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  DrawingPainter({required this.paths});
  @override
  void paint(Canvas canvas, Size size) {
    for (var drawingPath in paths) {
      canvas.drawPath(drawingPath.path, drawingPath.paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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
  StreamSubscription? _bridgeSubscription;
  bool _isBridgeInitialized = false;

  final List<String> _transcripts = [
    'Menginisialisasi bridge...'
  ];
  bool _isListening = false;
  final ScrollController _scrollController = ScrollController();

  final List<DrawingPath> _paths = [];
  DrawingPath? _currentPath;

  bool _isTranscriptMinimized = false;

  // --- Whiteboard features state ---
  Color _selectedColor = Colors.black;
  bool _isErasing = false;
  double _strokeWidth = 4.0;
  final TransformationController _transformationController = TransformationController();
  int _pointerCount = 0;
  bool _isDrawingMode = true;


  @override
  void initState() {
    super.initState();
    _sttBridge = context.read<AzureSttBridgeService>();
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
          _transcripts.clear();
          _transcripts.add('Tekan tombol mikrofon untuk mulai berbicara...');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _transcripts.add('Error initializing bridge: $e');
        });
      }
    }
  }

  @override
  void dispose() {
    _bridgeSubscription?.cancel();
    if (_isListening) {
      _sttBridge.stopListening();
    }
    _scrollController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _requestMicrophonePermission() async {
    await Permission.microphone.request();
  }

  void _listenToBridge() {
    _bridgeSubscription = _sttBridge.stream.listen((event) {
      final type = event['type'] as String;

      if (type == 'partial' || type == 'final') {
        final transcript = event['text'] as String;
        setState(() {
          if (_transcripts.length == 1 &&
              (_transcripts.first.startsWith('Tekan tombol') ||
                  _transcripts.first.startsWith('Menginisialisasi') ||
                  _transcripts.first == 'Mendengarkan...')) {
            _transcripts.clear();
          }
          if (type == "partial") {
            if (_transcripts.isNotEmpty && _transcripts.last.startsWith('Partial:')) {
              _transcripts.last = 'Partial: $transcript';
            } else {
              _transcripts.add('Partial: $transcript');
            }
          } else {
            if (_transcripts.isNotEmpty && _transcripts.last.startsWith('Partial:')) {
              _transcripts.removeLast();
            }
            _transcripts.add(transcript);
          }
        });
        _scrollToBottom();
      } else if (type == 'error') {
        final message = event['message'] as String;
        setState(() {
          _transcripts.add('Error: $message');
          _isListening = false;
        });
        _scrollToBottom();
      } else if (type == 'info') {
        final message = event['message'] as String;
        if (message == 'started') {
          setState(() {
            _isListening = true;
            _transcripts.clear();
            _transcripts.add('Mendengarkan...');
          });
        } else if (message == 'stopped' || message == 'session_stopped' || message == 'ws_closed') {
          setState(() {
            _isListening = false;
          });
        }
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _sttBridge.stopListening();
    } else {
      var status = await Permission.microphone.status;
      if (status.isGranted) {
        await _sttBridge.startListening();
      } else {
        setState(() => _transcripts.add('Izin mikrofon ditolak.'));
        _scrollToBottom();
      }
    }
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onPointerDown(PointerDownEvent details) {
    if (!_isDrawingMode) return;
    _pointerCount++;
    if (_pointerCount == 1) {
      final Matrix4 inverse = Matrix4.inverted(_transformationController.value);
      final vector.Vector3 transformedPosition = inverse.perspectiveTransform(vector.Vector3(details.localPosition.dx, details.localPosition.dy, 0));

      final paint = Paint()
        ..color = _isErasing ? Colors.transparent : _selectedColor
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..blendMode = _isErasing ? BlendMode.clear : BlendMode.srcOver;
        
      final path = Path()
        ..moveTo(transformedPosition.x, transformedPosition.y);
      setState(() {
        _currentPath = DrawingPath(path: path, paint: paint);
        if (_currentPath != null) _paths.add(_currentPath!);
      });
    }
  }

  void _onPointerMove(PointerMoveEvent details) {
    if (!_isDrawingMode) return;
    if (_pointerCount == 1 && _currentPath != null) {
      final Matrix4 inverse = Matrix4.inverted(_transformationController.value);
      final vector.Vector3 transformedPosition = inverse.perspectiveTransform(vector.Vector3(details.localPosition.dx, details.localPosition.dy, 0));
      setState(() => _currentPath!.path
          .lineTo(transformedPosition.x, transformedPosition.y));
    }
  }

  void _onPointerUp(PointerUpEvent details) {
    if (!_isDrawingMode) return;
    _pointerCount--;
    if (_pointerCount == 0) {
      setState(() => _currentPath = null);
    }
  }

  void _clearCanvas() => setState(() => _paths.clear());

  void _undo() {
    if (_paths.isNotEmpty) {
      setState(() {
        _paths.removeLast();
      });
    }
  }

  void _toggleEraser() {
    setState(() {
      _isErasing = !_isErasing;
    });
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
      _isErasing = false;
    });
  }

  void _toggleMode() {
    setState(() {
      _isDrawingMode = !_isDrawingMode;
    });
  }
  void _toggleTranscriptView() =>
      setState(() => _isTranscriptMinimized = !_isTranscriptMinimized);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header "Judul Sesi" tetap di atas
          _buildSessionHeader(),
          // Konten utama sekarang menggunakan Stack
          Expanded(
            child: Stack(
              children: [
                // LAPISAN 1: Papan Tulis (Latar Belakang)
                _buildWhiteboardPanel(),
                _buildFloatingTranscriptPanel(),
                _buildToolbar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Positioned(
      top: 20,
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
            IconButton(
              icon: Icon(Icons.edit),
              color: _isErasing ? Colors.blue : Colors.black,
              onPressed: _toggleEraser,
            ),
            IconButton(
              icon: Icon(_isDrawingMode ? Icons.pan_tool : Icons.edit),
              onPressed: _toggleMode,
            ),
            SizedBox(height: 10),
            _buildColorPalette(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
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
              border: _selectedColor == Colors.black ? Border.all(color: Colors.blue, width: 2) : null,
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
              border: _selectedColor == Colors.red ? Border.all(color: Colors.blue, width: 2) : null,
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
              border: _selectedColor == Colors.green ? Border.all(color: Colors.blue, width: 2) : null,
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
              border: _selectedColor == Colors.blue ? Border.all(color: Colors.blue, width: 2) : null,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildSessionHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 37, left: 24, right: 24, bottom: 10),
      child: Container(
        width:  MediaQuery.of(context).size.width * 0.3,
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
                onPressed: () {},
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

  Widget _buildWhiteboardPanel() {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.1,
        maxScale: 4.0,
        panEnabled: !_isDrawingMode,
        scaleEnabled: !_isDrawingMode,
        child: CustomPaint(
          size: Size.infinite,
          painter: DrawingPainter(paths: _paths),
          child: Container(
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingTranscriptPanel() {
    const primaryColor = Color(0xFF4A657D);

    return Positioned(
      top: 20,
      left: 20,
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: MediaQuery.of(context).size.width * 0.3,
          height: _isTranscriptMinimized ? 90 : 400,
          padding: const EdgeInsets.only(left: 25, right: 25, top: 20, bottom: 30),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Transkrip',
                        style: GoogleFonts.plusJakartaSans(
                            color: primaryColor, fontWeight: FontWeight.w600)),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_off,
                            color: Colors.white70),
                        onPressed: _isBridgeInitialized ? _toggleListening : null,
                      ),
                      IconButton(
                        icon: Icon(
                            _isTranscriptMinimized
                                ? Icons.open_in_full
                                : Icons.close_fullscreen,
                            color: Colors.white70),
                        onPressed: _toggleTranscriptView,
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isTranscriptMinimized) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white30),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _transcripts.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                      child: Text(
                        _transcripts[index],
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
