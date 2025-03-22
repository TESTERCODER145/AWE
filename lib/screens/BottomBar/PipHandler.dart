import 'package:flutter/services.dart';

class PiPService {
  static const MethodChannel _channel = MethodChannel('pip_channel');

  /// Starts Picture-in-Picture mode with a given video file path and position
  static Future<void> startPiP(String filePath, double position) async {
    try {
      await _channel.invokeMethod('startPip', {
        'path': filePath,
        'position': position,
      });
    } on PlatformException catch (e) {
      print("Error starting PiP: ${e.message}");
    }
  }

  /// Stops Picture-in-Picture mode
  static Future<void> stopPiP() async {
    try {
      await _channel.invokeMethod('stopPip');
    } on PlatformException catch (e) {
      print("Error stopping PiP: ${e.message}");
    }
  }

  /// Checks if Picture-in-Picture is supported on this device
  static Future<bool> isPiPSupported() async {
    try {
      return await _channel.invokeMethod('isPipSupported');
    } on PlatformException {
      return false;
    }
  }
}
