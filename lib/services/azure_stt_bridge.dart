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

  void sendPhraseList(List<String> phrases) {
  if (_ws != null && _ws!.readyState == WebSocket.open) {
    try {
      // Buat payload sesuai format yang diharapkan server
      final message = {
        "type": "set_phraselist",
        "payload": phrases,
      };
      
      final jsonString = json.encode(message);
      print('[SEND_PHRASELIST] Mengirim: $jsonString'); // Log untuk debugging
      _ws!.add(jsonString);
    } catch (e) {
      print('Error sending phrase list: $e');
    }
  } else {
    print('Gagal mengirim phrase list: WebSocket tidak terhubung.');
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
    if (_ws == null || _ws!.readyState != WebSocket.open) {
      throw StateError('Bridge not connected or WebSocket is not open.');
    }

    // 1. Kirim perintah 'start' ke server C#
    _ws!.add(json.encode({'type': 'start_listening'}));
    print('[CMD] Sent start_listening');

    // 2. Mulai streaming audio dari recorder
    final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
    _audioStreamSubscription = stream.listen(
      (data) {
        // Pastikan WebSocket masih terbuka sebelum mengirim data
        if (_ws != null && _ws!.readyState == WebSocket.open) {
          _ws!.add(data);
        }
      },
      onError: (error) {
        print('Audio stream error: $error');
        _controller.add({'type': 'error', 'message': 'Audio stream error: $error'});
        // Pertimbangkan untuk memanggil stopListening di sini untuk membersihkan
        stopListening();
      },
    );

    _controller.add({'type': 'info', 'message': 'started'});
  }

  Future<void> stopListening() async {
    if (_ws == null) return;

    // 1. Hentikan recorder dan batalkan subscription
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      print("Audio recorder and stream stopped.");
    } catch (e) {
      print("Error stopping audio recorder: $e");
      _controller.add({'type': 'error', 'message': 'Failed to stop recorder: $e'});
    }

    // 2. Kirim perintah 'stop' ke server C#
    if (_ws!.readyState == WebSocket.open) {
      _ws!.add(json.encode({'type': 'stop_listening'}));
      print('[CMD] Sent stop_listening');
    }

    // 3. Update UI state
    // Kirim pesan 'stopped' untuk memastikan UI diperbarui.
    _controller.add({'type': 'info', 'message': 'stopped'});
  }
}
