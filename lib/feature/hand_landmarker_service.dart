import 'dart:async';
import 'package:flutter/services.dart';

class HandLandmarkerService {
  static const MethodChannel _channel = MethodChannel('com.example.hear_me/hand_landmarker');
  
  final _resultStreamController = StreamController<List<List<Map<String, double>>>>.broadcast();
  Stream<List<List<Map<String, double>>>> get resultStream => _resultStreamController.stream;

  final _errorStreamController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorStreamController.stream;

  HandLandmarkerService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } on PlatformException catch (e) {
      print("Failed to initialize HandLandmarker: '${e.message}'.");
      _errorStreamController.add("Failed to initialize: ${e.message}");
    }
  }

  Future<void> detect(Uint8List imageBytes) async {
    try {
      // Fire and forget, results will come through the stream
      await _channel.invokeMethod('detect', {'image': imageBytes});
    } on PlatformException catch (e) {
      print("Failed to detect hand landmarks: '${e.message}'.");
      _errorStreamController.add("Failed to detect: ${e.message}");
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onResult':
        final dynamic result = call.arguments;
        if (result is List) {
          final landmarks = result.map((hand) {
            return (hand as List).map((point) {
              return (point as Map).map((key, value) => MapEntry(key.toString(), value as double));
            }).toList();
          }).toList();
          _resultStreamController.add(landmarks);
        }
        break;
      case 'onError':
        _errorStreamController.add(call.arguments as String);
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  void dispose() {
    _resultStreamController.close();
    _errorStreamController.close();
  }
}