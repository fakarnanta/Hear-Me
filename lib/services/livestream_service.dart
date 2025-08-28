import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hear_me/services/whiteboard_stream_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:rxdart/streams.dart';
import 'package:rxdart/subjects.dart';
import 'package:udp/udp.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LivestreamService {
  // Role
  final bool _isMaster;

  // Networking
  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSubscription;

  // State Controllers
  final _statusController = StreamController<String>.broadcast();
  final _transcriptsController =
      BehaviorSubject<List<String>>.seeded(['Menginisialisasi bridge...']);
  final _isListeningNotifier = ValueNotifier<bool>(false);
  final _pathsController = BehaviorSubject<List<DrawingPath>>.seeded([]);
  final _sessionStateController = StreamController<bool>.broadcast();
  final _isDiscoveringController = StreamController<bool>.broadcast();

  // Internal State
  final List<DrawingPath> _paths = [];
  DrawingPath? _currentPath;

  // Public Streams
  Stream<String> get statusStream => _statusController.stream;
  ValueStream<List<String>> get transcriptsStream =>
      _transcriptsController.stream;
  ValueNotifier<bool> get isListeningNotifier => _isListeningNotifier;
  ValueStream<List<DrawingPath>> get pathsStream => _pathsController.stream;
  BehaviorSubject<List<DrawingPath>> get pathsController => _pathsController;
  Stream<bool> get isSessionActiveStream => _sessionStateController.stream;
  Stream<bool> get isDiscoveringStream => _isDiscoveringController.stream;
  final _summaryController = StreamController<String>.broadcast();
  Stream<String> get summaryStream => _summaryController.stream;

  LivestreamService()
      : _isMaster =
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    _resetState();
  }

  void dispose() {
    _channel?.sink.close();
    _audioRecorder.dispose();
    _audioStreamSubscription?.cancel();
    _statusController.close();
    _transcriptsController.close();
    _isListeningNotifier.dispose();
    _pathsController.close();
    _sessionStateController.close();
    _isDiscoveringController.close();
    _summaryController.close();
  }

  // --- Public Methods for UI Interaction ---

  Future<void> toggleSession() async {
    if (_channel != null) {
      await _disconnect();
    } else {
      await _startUdpDiscovery();
    }
  }

  void sendSummary(String summary) {
    if (_channel != null) {
      // Kita bungkus dalam format JSON yang konsisten
      final message =
          jsonEncode({'type': 'summary_result', 'payload': summary});
      print('[SEND_SUMMARY] Mengirim rangkuman...');
      _channel!.sink.add(message);
    }
  }

  void onPointerDown(
      Offset position, Color color, double strokeWidth, bool isErasing) {
    final paint = Paint()
      ..color = isErasing ? Colors.transparent : color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = isErasing ? BlendMode.clear : BlendMode.srcOver;
    final path = Path()..moveTo(position.dx, position.dy);
    _currentPath = DrawingPath(path: path, paint: paint);
    if (_currentPath != null) {
      _paths.add(_currentPath!);
      _pathsController.add(List.from(_paths));
    }
    if (_isMaster) {
      _sendDrawEvent('draw_start', {
        'x': position.dx,
        'y': position.dy,
        'color': color.value,
        'strokeWidth': strokeWidth,
        'isErasing': isErasing,
      });
    }
  }

  void onPointerMove(Offset position) {
    if (_currentPath != null) {
      _currentPath!.path.lineTo(position.dx, position.dy);
      _pathsController.add(List.from(_paths));
    }
    if (_isMaster) {
      _sendDrawEvent('draw_move', {
        'x': position.dx,
        'y': position.dy,
      });
    }
  }

  void onPointerUp() {
    _currentPath = null;
    if (_isMaster) {
      _sendDrawEvent('draw_end', {});
    }
  }

  void clear() {
    _paths.clear();
    _pathsController.add([]);
    if (_isMaster) {
      _sendDrawEvent('clear', {});
    }
  }

  void undo() {
    if (_paths.isNotEmpty) {
      _paths.removeLast();
      _pathsController.add(List.from(_paths));
    }
    if (_isMaster) {
      _sendDrawEvent('undo', {});
    }
  }

  // --- Private Helper Methods ---

  void _sendDrawEvent(String type, Map<String, dynamic> payload) {
    if (_channel == null) return;
    final message = jsonEncode({'type': type, 'payload': payload});
    _channel!.sink.add(message);
  }

  void _resetState({String? error}) {
    _channel = null;
    _paths.clear();
    _currentPath = null;
    _isDiscoveringController.add(false);
    _sessionStateController.add(false);
    _statusController.add(error ?? "Terputus");
    _transcriptsController.add([
      _isMaster
          ? "Tekan tombol untuk menjadi host sesi transkripsi..."
          : "Tekan tombol untuk bergabung dan melihat sesi transkripsi...",
    ]);
    _isListeningNotifier.value = false;
    _pathsController.add([]);
  }

  void addTranscript(String transcript) {
    final currentTranscripts = _transcriptsController.value;
    if (currentTranscripts.isEmpty ||
        currentTranscripts.first.startsWith('Tekan tombol') ||
        currentTranscripts.first.startsWith('Menginisialisasi') ||
        currentTranscripts.first == 'Mendengarkan...') {
      _transcriptsController.add([transcript]);
    } else {
      final updatedTranscripts = List<String>.from(currentTranscripts);
      updatedTranscripts[updatedTranscripts.length - 1] = transcript;
      _transcriptsController.add(updatedTranscripts);
    }
  }

  void startListening() {
    _isListeningNotifier.value = true;
    _transcriptsController.add(['Mendengarkan...']);
  }

  void stopListening() {
    _isListeningNotifier.value = false;
    _transcriptsController.add(['Mendengarkan dihentikan.']);
  }

  Future<void> _startUdpDiscovery() async {
    if (_isDiscoveringController.isClosed ||
        !_isDiscoveringController.hasListener) return;

    _isDiscoveringController.add(true);
    _statusController.add("Mencari server...");

    const int discoveryPort = 8888;
    const String discoveryMessage = "hilmi_stt_discovery_request";

    try {
      var udp = await UDP.bind(Endpoint.any());
      var broadcastEndpoint =
          Endpoint.broadcast(port: const Port(discoveryPort));
      await udp.send(utf8.encode(discoveryMessage), broadcastEndpoint);

      await for (var datagram
          in udp.asStream(timeout: const Duration(seconds: 10))) {
        if (datagram != null) {
          var responseStr = utf8.decode(datagram.data);
          if (responseStr == discoveryMessage) continue;
          var responseJson = jsonDecode(responseStr);
          udp.close();
          await _connect(responseJson['host'], responseJson['port']);
          return;
        }
      }
      udp.close();
      _resetState(error: "Server tidak ditemukan");
    } catch (e) {
      _resetState(error: "Error saat discovery: $e");
    }
  }

  Future<void> _connect(String host, int port) async {
    _statusController.add("Menghubungkan...");
    final wsUrl = Uri.parse('ws://$host:$port');
    _channel = WebSocketChannel.connect(wsUrl);
    _sessionStateController.add(true);

    _channel!.stream.listen(
      (message) {
        try {
          final decodedMessage = jsonDecode(message);
          _handleWebSocketMessage(decodedMessage);
        } catch (e) {
          print("Failed to process message: $e");
        }
      },
      onDone: () => _resetState(error: "Koneksi terputus"),
      onError: (error) => _resetState(error: "Koneksi error"),
    );
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];
    final payload = message['payload'];

    switch (type) {
      case 'connection_ack':
        _isDiscoveringController.add(false);
        _statusController.add(_isMaster
            ? "Terhubung sebagai Master"
            : "Terhubung sebagai Penonton");
        _transcriptsController.add(["Menunggu transkripsi..."]);
        if (_isMaster) {
          _startStreamingAudio();
        }
        break;
      case 'transcription':
        addTranscript(payload['text']);
        break;
      case 'draw_start':
        final paint = Paint()
          ..color = Color(payload['color'])
          ..strokeWidth = payload['strokeWidth']
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..blendMode =
              payload['isErasing'] ? BlendMode.clear : BlendMode.srcOver;
        final path = Path()..moveTo(payload['x'], payload['y']);
        _currentPath = DrawingPath(path: path, paint: paint);
        if (_currentPath != null) {
          _paths.add(_currentPath!);
          _pathsController.add(List.from(_paths));
        }
        break;
      case 'draw_move':
        if (_currentPath != null) {
          _currentPath!.path.lineTo(payload['x'], payload['y']);
          _pathsController.add(List.from(_paths));
        }
        break;
      case 'draw_end':
        _currentPath = null;
        break;
      case 'clear':
        _paths.clear();
        _pathsController.add([]);
        break;
      case 'undo':
        if (_paths.isNotEmpty) {
          _paths.removeLast();
          _pathsController.add(List.from(_paths));
        }
        break;

      case 'summary_result':
        print("Menerima rangkuman: $payload");
        _summaryController.add(payload as String);
        break;
    }
  }

  Future<void> _startStreamingAudio() async {
    if (!await Permission.microphone.request().isGranted) {
      return _resetState(error: "Izin mikrofon ditolak");
    }
    final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
    _audioStreamSubscription =
        stream.listen((data) => _channel?.sink.add(data));
    _statusController.add("Merekam & Mengirim Audio");
  }

  Future<void> _disconnect() async {
    try {
      if (_isMaster) {
        await _audioRecorder.stop();
        _audioStreamSubscription?.cancel();
      }
      _channel?.sink.close();
      _resetState(error: "Sesi dihentikan");
    } catch (e) {
      _resetState(error: "Error saat berhenti");
    }
  }
}
