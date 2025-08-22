import 'dart:async';
import 'dart:convert';
import 'dart:io';

class AzureSttBridgeService {
  Process? _proc;
  WebSocket? _ws;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

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

    _ws = await WebSocket.connect('ws://127.0.0.1:5005/stt');

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
    _ws!.add('START');
  }

  Future<void> stopListening() async {
    if (_ws == null) return;
    _ws!.add('STOP');
  }
}
