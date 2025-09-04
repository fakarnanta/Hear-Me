import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hear_me/services/azure_stt_bridge.dart';
import 'package:hear_me/services/whiteboard_stream_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:rxdart/streams.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udp/udp.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TranscriptEntry {
  final String speakerId;
  final String text;
  final Color color;

  TranscriptEntry({
    required this.speakerId,
    required this.text,
    required this.color,
  });
}

class LivestreamService {
  final bool _isMaster;
  final AzureSttBridgeService? _sttBridge;
  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSubscription;

  final _statusController = StreamController<String>.broadcast();
  final _transcriptsController = BehaviorSubject<List<TranscriptEntry>>.seeded([]);
  final _partialTranscriptController = BehaviorSubject<TranscriptEntry?>.seeded(null);
  final _isListeningNotifier = ValueNotifier<bool>(false);
  final _pathsController = BehaviorSubject<List<DrawingPath>>.seeded([]);
  final _currentUtteranceController = BehaviorSubject<TranscriptEntry?>.seeded(null);
  final _sessionStateController = StreamController<bool>.broadcast();
  final _isDiscoveringController = StreamController<bool>.broadcast();
  final _summaryController = StreamController<String>.broadcast();
  final _handRaiseController = StreamController<String>.broadcast();

  final List<Color> _colorPalette = [
    Colors.blue.shade300, Colors.green.shade300, Colors.red.shade300,
    Colors.orange.shade300, Colors.purple.shade300, Colors.teal.shade300,
  ];
  final Map<String, Color> _speakerColors = {};
  int _nextColorIndex = 0;

  final List<DrawingPath> _paths = [];
  DrawingPath? _currentPath;

  Stream<String> get statusStream => _statusController.stream;
  ValueStream<List<TranscriptEntry>> get transcriptsStream => _transcriptsController.stream;
  ValueStream<TranscriptEntry?> get partialTranscriptStream => _partialTranscriptController.stream;
  ValueNotifier<bool> get isListeningNotifier => _isListeningNotifier;
  ValueStream<List<DrawingPath>> get pathsStream => _pathsController.stream;
  Stream<bool> get isSessionActiveStream => _sessionStateController.stream;
  Stream<bool> get isDiscoveringStream => _isDiscoveringController.stream;
  Stream<String> get summaryStream => _summaryController.stream;
  Stream<String> get handRaiseStream => _handRaiseController.stream;

  String? currentSessionId;

  LivestreamService({AzureSttBridgeService? sttBridge})
      : _isMaster = (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows),
        _sttBridge = sttBridge {
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
    _handRaiseController.close();
    _partialTranscriptController.close();
  }

  Future<void> toggleSession() async {
    if (_channel != null) {
      await _disconnect();
    } else {
      await _startUdpDiscovery();
    }
  }

  void sendPhraseList(List<String> phrases) {
    if (_channel != null) {
      final message = jsonEncode({'type': 'set_phraselist', 'payload': phrases});
      print('[SEND_PHRASELIST] Mengirim: $message');
      _channel!.sink.add(message);
    }
  }

  void sendSummary(String summary) {
    if (_channel != null) {
      final message = jsonEncode({'type': 'summary_result', 'payload': summary});
      _channel!.sink.add(message);
    }
  }

  void raiseHand(String userName) {
    if (_channel != null && !_isMaster) { // Only clients can raise hands
      print('[SEND] raise_hand');
      final message = jsonEncode({'type': 'raise_hand', 'payload': {'userName': userName}});
      _channel!.sink.add(message);
    }
  }

  void startListening() {
    _isListeningNotifier.value = true;
    final listeningEntry = TranscriptEntry(speakerId: "System", text: "Mendengarkan...", color: Colors.grey);
    _transcriptsController.add([listeningEntry]);
  }

  void stopListening() {
    _isListeningNotifier.value = false;
    final stoppedEntry = TranscriptEntry(speakerId: "System", text: "Mendengarkan dihentikan.", color: Colors.grey);
    addTranscript(stoppedEntry);
  }

  void setPartialTranscript(TranscriptEntry? entry) {
    _partialTranscriptController.add(entry);
  }

  void clearPartialTranscript() {
    _partialTranscriptController.add(null);
  }

  void onPointerDown(Offset position, Color color, double strokeWidth, bool isErasing) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = isErasing ? BlendMode.clear : BlendMode.srcOver
      ..isAntiAlias = !isErasing;
      
    final path = Path()..moveTo(position.dx, position.dy);
    _currentPath = DrawingPath(path: path, paint: paint);
    _paths.add(_currentPath!);
    _pathsController.add(List.from(_paths));
    
    if (_isMaster) {
      print('[SEND] draw_start');
      _sendDrawEvent('draw_start', {
        'x': position.dx, 'y': position.dy, 'color': color.value,
        'strokeWidth': strokeWidth, 'isErasing': isErasing,
      });
    }
  }

  void onPointerMove(Offset position) {
    if (_currentPath != null) {
      _currentPath!.path.lineTo(position.dx, position.dy);
      _pathsController.add(List.from(_paths));
    }
    if (_isMaster) {
      print('[SEND] draw_move');
      _sendDrawEvent('draw_move', {'x': position.dx, 'y': position.dy});
    }
  }

  void onPointerUp() {
    _currentPath = null;
    if (_isMaster) {
      print('[SEND] draw_end');
      _sendDrawEvent('draw_end', {});
    }
  }

  void clear() {
    _paths.clear();
    _pathsController.add([]);
    if (_isMaster) {
      print('[SEND] clear');
      _sendDrawEvent('clear', {});
    }
  }

  void undo() {
    if (_paths.isNotEmpty) {
      _paths.removeLast();
      _pathsController.add(List.from(_paths));
    }
    if (_isMaster) {
      print('[SEND] undo');
      _sendDrawEvent('undo', {});
    }
  }

  Color getColorForSpeaker(String speakerId) {
    if (_speakerColors.containsKey(speakerId)) return _speakerColors[speakerId]!;
    
    final newColor = _colorPalette[_nextColorIndex];
    _speakerColors[speakerId] = newColor;
    _nextColorIndex = (_nextColorIndex + 1) % _colorPalette.length;
    return newColor;
  }

  void _sendDrawEvent(String type, Map<String, dynamic> payload) {
    if (_isMaster) {
      if (_sttBridge == null) {
        print('[DEBUG WINDOWS] GAGAL: _sendDrawEvent dipanggil TAPI _sttBridge null.');
        return;
      }
      final message = {'type': type, 'payload': payload};
      _sttBridge!.sendWhiteboardData(message);
    } else {
      if (_channel == null) {
        print('[DEBUG MOBILE] GAGAL: _sendDrawEvent dipanggil TAPI channel null.');
        return;
      }
      final message = jsonEncode({'type': type, 'payload': payload});
      _channel!.sink.add(message);
    }
  }
  
  void addTranscript(TranscriptEntry newEntry) {
    final currentTranscripts = _transcriptsController.value;
    if (currentTranscripts.isEmpty || currentTranscripts.first.speakerId == "System") {
      _transcriptsController.add([newEntry]);
    } else {
      final lastEntry = currentTranscripts.last;
      if (lastEntry.speakerId == newEntry.speakerId) {
        final updatedEntry = TranscriptEntry(
          speakerId: lastEntry.speakerId,
          text: "${lastEntry.text} ${newEntry.text}",
          color: lastEntry.color,
        );
        currentTranscripts[currentTranscripts.length - 1] = updatedEntry;
      } else {
        currentTranscripts.add(newEntry);
      }
      _transcriptsController.add(List.from(currentTranscripts));
    }
  }

  void handleBridgeMessage(Map<String, dynamic> message) {
    _handleMessage(message);
  }

  void _handleMessage(Map<String, dynamic> message) {
    print('[DEBUG MOBILE] Menerima pesan: $message');
    final type = message['type'] as String?;
    final payload = message['payload'];
    switch (type) {
      case 'connection_ack':
        _isDiscoveringController.add(false);
        _statusController.add(_isMaster ? "Terhubung sebagai Master" : "Terhubung sebagai Penonton");
        _transcriptsController.add([
          TranscriptEntry(speakerId: "System", text: "Menunggu transkripsi...", color: Colors.grey)
        ]);
        if (currentSessionId != null) {
          SharedPreferences.getInstance().then((prefs) {
            final String? vocabulariesJson = prefs.getString('all_vocabularies');
            if (vocabulariesJson != null) {
              final Map<String, dynamic> decodedMap = json.decode(vocabulariesJson);
              final Map<String, List<String>> allVocabularies = decodedMap.map((key, value) => MapEntry(key, List<String>.from(value)));
              final vocabulary = allVocabularies[currentSessionId] ?? [];
              if (vocabulary.isNotEmpty) {
                sendPhraseList(vocabulary);
              }
            }
          });
        }
        if (_isMaster) _startStreamingAudio();
        break;
        
      case 'transcription_partial':
        final text = payload['text'] as String?;
        if (text != null && text.isNotEmpty) {
          final lastEntry = _transcriptsController.value.lastOrNull;
          // Gunakan speaker ID dari entri terakhir agar warna konsisten
          final speakerId = lastEntry?.speakerId ?? '...';
          final color = getColorForSpeaker(speakerId);
          _partialTranscriptController.add(TranscriptEntry(speakerId: speakerId, text: text, color: color));
        }
        break;
      
      case 'transcription_final':
        final text = payload['text'] as String?;
        final speakerId = payload['speakerId'] as String? ?? 'Speaker';
        if (text != null && text.isNotEmpty) {
          final color = getColorForSpeaker(speakerId);
          // Panggil 'addTranscript' yang sudah pintar untuk menggabungkan atau menambah entri baru
          addTranscript(TranscriptEntry(speakerId: speakerId, text: text, color: color));
          // Kosongkan stream parsial setelah hasil final diterima
          _partialTranscriptController.add(null);
        }
        break;
        
      case 'partial_transcription':
        final text = payload['text'] as String;
        if (text.isNotEmpty) {
          final speakerId = payload['speakerId'] as String? ?? '...';
          final color = getColorForSpeaker(speakerId);
          _partialTranscriptController.add(TranscriptEntry(speakerId: speakerId, text: text, color: color));
        }
        break;
      
      case 'transcription':
        final text = payload['text'] as String;
        final speakerId = payload['speakerId'] as String? ?? 'Speaker';
        final color = getColorForSpeaker(speakerId);
        addTranscript(TranscriptEntry(speakerId: speakerId, text: text, color: color));
        _partialTranscriptController.add(null);
        break;

      case 'summary_result':
        _summaryController.add(payload as String);
        break;

      case 'raise_hand':
        print('[RECV] raise_hand');
        if (_isMaster) { // Only the host processes this
          final userName = payload['userName'] as String? ?? 'Unknown User';
          _handRaiseController.add(userName);
        }
        break;
      
      case 'draw_start':
        print('[RECV] draw_start');
        final paint = Paint()
          ..color = Color(payload['color'])
          ..strokeWidth = (payload['strokeWidth'] as num).toDouble()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..blendMode = payload['isErasing'] ? BlendMode.clear : BlendMode.srcOver
          ..isAntiAlias = !payload['isErasing'];
        final path = Path()..moveTo((payload['x'] as num).toDouble(), (payload['y'] as num).toDouble());
        _currentPath = DrawingPath(path: path, paint: paint);
        _paths.add(_currentPath!);
        _pathsController.add(List.from(_paths));
        break;

      case 'draw_move':
        print('[RECV] draw_move');
        if (_currentPath != null) {
          _currentPath!.path.lineTo((payload['x'] as num).toDouble(), (payload['y'] as num).toDouble());
          _pathsController.add(List.from(_paths));
        }
        break;

      case 'draw_end':
        print('[RECV] draw_end');
        _currentPath = null;
        break;
      case 'clear':
        print('[RECV] clear');
        _paths.clear();
        _pathsController.add([]);
        break;
      case 'undo':
        print('[RECV] undo');
        if (_paths.isNotEmpty) {
          _paths.removeLast();
          _pathsController.add(List.from(_paths));
        }
        break;
    }
  }

  void _resetState({String? error}) {
    _channel = null;
    _paths.clear();
    _currentPath = null;
    _speakerColors.clear();
    _nextColorIndex = 0;

    _isDiscoveringController.add(false);
    _sessionStateController.add(false);
    _statusController.add(error ?? "Terputus");

    final initialMessage = _isMaster 
      ? "Tekan tombol untuk menjadi host sesi transkripsi..."
      : "Tekan tombol untuk bergabung dan melihat sesi transkripsi...";
    _transcriptsController.add([
      TranscriptEntry(speakerId: "System", text: initialMessage, color: Colors.grey)
    ]);
    
    _isListeningNotifier.value = false;
    _pathsController.add([]);
  }

  Future<void> _startUdpDiscovery() async {
    _isDiscoveringController.add(true);
    _statusController.add("Mencari server...");
    const discoveryPort = 8888;
    const discoveryMessage = "hilmi_stt_discovery_request";

    try {
      var udp = await UDP.bind(Endpoint.any());
      var broadcastEndpoint = Endpoint.broadcast(port: const Port(discoveryPort));
      await udp.send(utf8.encode(discoveryMessage), broadcastEndpoint);

      await for (var datagram in udp.asStream(timeout: const Duration(seconds: 10))) {
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
          final decodedMessage = jsonDecode(message) as Map<String, dynamic>;
          _handleMessage(decodedMessage);
        } catch (e) {
          print("Gagal memproses pesan: $e");
        }
      },
      onDone: () => _resetState(error: "Koneksi terputus"),
      onError: (error) => _resetState(error: "Koneksi error"),
    );
  }

  Future<void> _startStreamingAudio() async {
    if (!await Permission.microphone.request().isGranted) {
      return _resetState(error: "Izin mikrofon ditolak");
    }
    final stream = await _audioRecorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
    _audioStreamSubscription = stream.listen((data) => _channel?.sink.add(data));
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