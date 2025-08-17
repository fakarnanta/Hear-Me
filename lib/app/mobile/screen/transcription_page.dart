
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class TranscriptionPage extends StatefulWidget {
  const TranscriptionPage({super.key});

  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  static const methodChannel = MethodChannel('com.example.hilmi/azure/method');
  static const eventChannel = EventChannel('com.example.hilmi/azure/event');

  String _transcribedText = 'Tekan tombol mikrofon untuk mulai berbicara...';
  bool _isListening = false;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _requestMicrophonePermission();
    _configureStreamListener();
  }

  Future<void> _requestMicrophonePermission() async {
    await Permission.microphone.request();
  }

  void _configureStreamListener() {
    _eventSubscription = eventChannel.receiveBroadcastStream().listen((dynamic event) {
      setState(() {
        _transcribedText = event.toString();
      });
    }, onError: (dynamic error) {
      setState(() {
        _transcribedText = 'Error: ${error.message}';
        _isListening = false;
      });
    });
  }
  
  // Fungsi untuk memulai atau menghentikan proses
  Future<void> _toggleListening() async {
    if (_isListening) {
      try {
        await methodChannel.invokeMethod('stopListening');
        setState(() => _isListening = false);
      } on PlatformException catch (e) {
        setState(() => _transcribedText = "Gagal berhenti: '${e.message}'.");
      }
    } else {
      var status = await Permission.microphone.status;
      if (status.isGranted) {
        try {
          await methodChannel.invokeMethod('startListening');
          setState(() {
            _isListening = true;
            _transcribedText = 'Mendengarkan...';
          });
        } on PlatformException catch (e) {
          setState(() => _transcribedText = "Gagal memulai: '${e.message}'.");
        }
      } else {
        setState(() => _transcribedText = 'Izin mikrofon ditolak.');
      }
    }
  }
  
  @override
  void dispose() {
    _eventSubscription?.cancel();
    if (_isListening) {
      methodChannel.invokeMethod('stopListening');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Transcription'),
        backgroundColor: _isListening ? Colors.redAccent : Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Hasil Transkripsi:',
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      _transcribedText,
                      style: const TextStyle(fontSize: 18.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleListening,
        backgroundColor: _isListening ? Colors.red : Colors.blue,
        child: Icon(_isListening ? Icons.stop : Icons.mic),
      ),
    );
  }
}