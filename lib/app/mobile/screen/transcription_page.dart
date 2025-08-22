
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/constant.dart';
import 'package:line_icons/line_icon.dart';
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
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical : 37, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(5),
              width: MediaQuery.of(context).size.width * 1,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  IconButton(onPressed: () {}, icon: LineIcon.arrowLeft(), color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Judul Sesi',
                    style: GoogleFonts.plusJakartaSans( 
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: MediaQuery.of(context).size.width * 1,
              height: 340,
              padding: const EdgeInsets.only(left: 25, right: 25, top: 20, bottom: 30),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 42,
                    width: 110,
                    decoration: BoxDecoration(
                      color: Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Center(
                      child: Text(
                        'Transkrip',
                        style: GoogleFonts.plusJakartaSans(
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 15,),
                  SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      _transcribedText,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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