import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:record/record.dart';

class AzureSttBridgeService {
  Process? _proc;
  WebSocket? _ws;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _audioRecorder = AudioRecorder();
  StreamSubscription? _audioStreamSubscription;


  Stream<Map<String, dynamic>> get stream => _controller.stream;

    void sendWhiteboardData(Map<String, dynamic> data) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      try {
        final jsonString = json.encode(data);
        print('[SEND_WHITEBOARD] $jsonString'); // Log untuk debugging
        _ws!.add(jsonString);
      } catch (e) {
        print('Error sending whiteboard data: $e');
      }
    }
  }

  Future<void> startBridgeExe() async {
    // jalankan EXE bridge
    final exePath = Platform.isWindows
        ? 'windows/bridge/AzureSttBridge.exe'
        : throw UnsupportedError('Windows only');
    _proc = await Process.start(
      exePath,
      [],
      workingDirectory: Directory.current.path,
      runInShell: true,
    );

    // forward log ke debug console
    _proc!.stdout.transform(utf8.decoder).listen((data) {
      // ignore or print
      print('[BRIDGE] $data');
    });
    _proc!.stderr.transform(utf8.decoder).listen((data) {
      print('[BRIDGE-ERR] $data');
    });

    // tunggu bridge siap lalu connect websocket
    // sedikit delay memberi waktu HttpListener start
    await Future.delayed(const Duration(milliseconds: 1500));

    _ws = await WebSocket.connect('ws://127.0.0.1:8080');

    _ws!.listen((raw) {
      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        _controller.add(map);
      } catch (_) {
        _controller.add({'type': 'raw', 'text': raw.toString()});
      }
    }, onDone: () {
      _controller.add({'type': 'info', 'message': 'ws_closed'});
    }, onError: (e) {
      _controller.add({'type': 'error', 'message': e.toString()});
    });
  }

  Future<void> stopBridgeExe() async {
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;

    if (_proc != null) {
      _proc!.kill();
      _proc = null;
    }
  }

  Future<void> startListening({String? language}) async {
    if (_ws == null) throw StateError('Bridge not connected');
    if (language != null) {
      _ws!.add(json.encode({'cmd': 'LANG', 'value': language}));
    }
    
    final stream = await _audioRecorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
    _audioStreamSubscription = stream.listen((data) {
      _ws?.add(data);
    });

    _controller.add({'type': 'info', 'message': 'started'});
  }

Future<void> stopListening() async {
  if (_ws == null) return;
  
  try {
    print("Mencoba menghentikan audio recorder...");
    await _audioRecorder.stop();
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null; // Bersihkan subscription setelah dibatalkan
    print("Audio recorder berhasil dihentikan.");
  } catch (e) {
    print("Error saat menghentikan audio recorder: $e");
    // Kirim pesan error ke UI jika diperlukan
    _controller.add({'type': 'error', 'message': 'Gagal berhenti: $e'});
  } finally {
    // Kirim pesan konfirmasi 'stopped' ke UI di dalam blok finally.
    // Ini menjamin _isListening akan di-set ke false di UI.
    _controller.add({'type': 'info', 'message': 'stopped'});
  }
}
}
