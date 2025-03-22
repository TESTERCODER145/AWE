import 'package:flutter/services.dart';

class PiPService {
  static const MethodChannel _channel = MethodChannel('pip_channel');
  
  // Event callbacks
  static Function? onPiPStarted;
  static Function? onPiPStopped;
  static Function(String)? onPiPError;
  static Function? onFullscreenRestore;
  
  static bool _isInitialized = false;

  /// Initialize the PiP service and set up method call handlers
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _channel.setMethodCallHandler(_handleMethodCall);
    _isInitialized = true;
  }
  
  /// Handles method calls from the native platform
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPiPStarted':
        onPiPStarted?.call();
        break;
      case 'onPiPStopped':
        onPiPStopped?.call();
        break;
      case 'onPiPError':
        final errorMessage = call.arguments as String;
        onPiPError?.call(errorMessage);
        break;
      case 'onRestoreFullScreen':
        onFullscreenRestore?.call();
        break;
      default:
        print('Unknown method call from native: ${call.method}');
    }
  }

  /// Starts Picture-in-Picture mode with a given video file path and position
  static Future<bool> startPiP(String filePath, [double position = 0]) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      await _channel.invokeMethod('startPip', {
        'path': filePath,
        'position': position,
      });
      return true;
    } on PlatformException catch (e) {
      print("Error starting PiP: ${e.message}");
      onPiPError?.call(e.message ?? "Unknown error starting PiP");
      return false;
    }
  }

  /// Stops Picture-in-Picture mode
  static Future<bool> stopPiP() async {
    try {
      await _channel.invokeMethod('stopPip');
      return true;
    } on PlatformException catch (e) {
      print("Error stopping PiP: ${e.message}");
      onPiPError?.call(e.message ?? "Unknown error stopping PiP");
      return false;
    }
  }

  /// Checks if Picture-in-Picture is supported on this device
  static Future<bool> isPiPSupported() async {
    try {
      return await _channel.invokeMethod('isPipSupported') ?? false;
    } on PlatformException catch (e) {
      print("Error checking PiP support: ${e.message}");
      return false;
    }
  }
  
  
  
  /// Gets the current PiP state (if active)
  static Future<bool> isPiPActive() async {
    try {
      final bool? isActive = await _channel.invokeMethod('isPipActive');
      return isActive ?? false;
    } on PlatformException catch (e) {
      print("Error checking PiP active state: ${e.message}");
      return false;
    }
  }
  
  /// Disposes resources and removes method handlers
  static void dispose() {
    onPiPStarted = null;
    onPiPStopped = null;
    onPiPError = null;
    onFullscreenRestore = null;
    
    // Cannot directly remove method handler, but we can set it to a no-op function
    _channel.setMethodCallHandler((call) async {});
    
    _isInitialized = false;
  }
}