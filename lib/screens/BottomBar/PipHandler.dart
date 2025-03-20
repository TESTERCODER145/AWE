import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PipHandler {
  static const _methodChannel = MethodChannel('pip_channel');
  static const _eventChannel = EventChannel('pip_events');
  static Stream<bool>? _pipStateStream;

  /// Initialize PiP listener (call in main())
  static void initialize() {
    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// Check if PiP is supported on the device
  static Future<bool> get isSupported async {
    try {
      return await _methodChannel.invokeMethod('isPipSupported');
    } on PlatformException {
      return false;
    }
  }

  /// Start PiP mode with current video
  static Future<void> startPip({
    required String videoPath,
    required Duration position,
  }) async {
    try {
      await _methodChannel.invokeMethod('startPip', {
        'path': videoPath,
        'position': position.inMilliseconds.toDouble(),
      });
    } on PlatformException catch (e) {
      debugPrint("PiP Start Error: ${e.message}");
    }
  }

  /// Stop PiP mode
  static Future<void> stopPip() async {
    try {
      await _methodChannel.invokeMethod('stopPip');
    } on PlatformException catch (e) {
      debugPrint("PiP Stop Error: ${e.message}");
    }
  }

  /// Stream of PiP state changes
  static Stream<bool> get pipState {
    _pipStateStream ??= _eventChannel
        .receiveBroadcast()
        .map((event) => event == 'started');
    return _pipStateStream!;
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPiPStarted':
        // Handle any additional logic on PiP start
        break;
      case 'onPiPStopped':
        // Handle any additional logic on PiP stop
        break;
    }
    return null;
  }
}