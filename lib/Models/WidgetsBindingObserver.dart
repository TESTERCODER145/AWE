import 'package:downloadsplatform/Models/SessionManager.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:downloadsplatform/Models/auth_provider.dart';

class AppLifecycleTracker with WidgetsBindingObserver {
  final SessionManager _sessionManager = SessionManager();
  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  BuildContext? _context; // Store the BuildContext

  void initialize(BuildContext context) {
    _context = context; // Initialize the BuildContext
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_context == null) return; // Ensure context is available

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed(_context!); // Pass the context
        break;
      case AppLifecycleState.paused:
        _onAppPaused(_context!); // Pass the context
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  void _onAppResumed(BuildContext context) async {
    _sessionStartTime = DateTime.now().toUtc();
    _sessionTimer?.cancel(); // Cancel any existing timer
    _sessionTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _sendPeriodicSessionUpdate(context);
    });

    // Fetch the operating system
    final operatingSystem = await getOperatingSystem();

    // Get the authentication status from UserProvider
    final authProvider = Provider.of<UserProvider>(context, listen: false);
    final isAuthenticated = authProvider.isAuthenticated;

    // Send session start request
    _sessionManager.sendSessionRequest(
      startTime: _sessionStartTime!.toIso8601String(),
      endTime: _sessionStartTime!.toIso8601String(), // Same as start time for initial request
      isAuthenticated: isAuthenticated, // Use the actual authentication status
      operatingSystem: operatingSystem, // Pass the fetched operating system
    );
  }

  void _onAppPaused(BuildContext context) async {
    _sessionTimer?.cancel();
    final sessionEndTime = DateTime.now().toUtc();

    // Fetch the operating system
    final operatingSystem = await getOperatingSystem();

    // Get the authentication status from UserProvider
    final authProvider = Provider.of<UserProvider>(context, listen: false);
    final isAuthenticated = authProvider.isAuthenticated;

    // Send session end request
    _sessionManager.sendSessionRequest(
      startTime: _sessionStartTime!.toIso8601String(),
      endTime: sessionEndTime.toIso8601String(),
      isAuthenticated: isAuthenticated, // Use the actual authentication status
      operatingSystem: operatingSystem, // Pass the fetched operating system
    );
  }

  void _sendPeriodicSessionUpdate(BuildContext context) async {
    final sessionEndTime = DateTime.now().toUtc();

    // Fetch the operating system
    final operatingSystem = await getOperatingSystem();

    // Get the authentication status from UserProvider
    final authProvider = Provider.of<UserProvider>(context, listen: false);
    final isAuthenticated = authProvider.isAuthenticated;

    // Send periodic session update
    _sessionManager.sendSessionRequest(
      startTime: _sessionStartTime!.toIso8601String(),
      endTime: sessionEndTime.toIso8601String(),
      isAuthenticated: isAuthenticated, // Use the actual authentication status
      operatingSystem: operatingSystem, // Pass the fetched operating system
    );
  }

  Future<String> getOperatingSystem() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return 'Android ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return 'iOS ${iosInfo.systemVersion}';
    } else if (Platform.isWindows) {
      final WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
      return 'Windows ${windowsInfo.computerName}';
    } else if (Platform.isMacOS) {
      final MacOsDeviceInfo macOsInfo = await deviceInfo.macOsInfo;
      return 'macOS ${macOsInfo.osRelease}';
    } else if (Platform.isLinux) {
      final LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
      return 'Linux ${linuxInfo.id}';
    } else {
      return 'Unknown OS';
    }
  }
}