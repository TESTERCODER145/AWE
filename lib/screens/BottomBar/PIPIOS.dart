import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class PiPVideoPlayer extends StatefulWidget {
  final String filePath;

  const PiPVideoPlayer({Key? key, required this.filePath}) : super(key: key);

  @override
  _PiPVideoPlayerState createState() => _PiPVideoPlayerState();
}

class _PiPVideoPlayerState extends State<PiPVideoPlayer> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isInPipMode = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  
  // Create a method channel to communicate with native code
  final MethodChannel _pipChannel = const MethodChannel('pip_channel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideoPlayer();
    // Setup PiP event listeners for iOS
    _setupPipListeners();
  }

  void _setupPipListeners() {
    _pipChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPiPStarted':
          setState(() => _isInPipMode = true);
          break;
        case 'onPiPStopped':
          setState(() => _isInPipMode = false);
          break;
        case 'onPiPError':
          print("PiP Error: ${call.arguments}");
          break;
        case 'onRestoreFullScreen':
          // Handle restoration to full screen if needed
          break;
      }
    });
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.file(File(widget.filePath));
      await _controller.initialize();
      
      setState(() {
        _isInitialized = true;
        // Auto-play when initialized
        _controller.play();
        _isPlaying = true;
      });

      // Start the controls auto-hide timer
      _startControlsTimer();
    } catch (e) {
      print("Video initialization error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: $e')),
        );
      }
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _controlsTimer?.cancel();
    // Ensure PiP is cleaned up
    if (_isInPipMode) {
      _exitPipMode();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_isInPipMode && _isPlaying) {
      // App is going to background, enter PiP if playing
      _enterPipMode();
    }
  }

  Future<void> _enterPipMode() async {
    if (!_isInitialized) return;
    
    try {
      bool isPipSupported = await _pipChannel.invokeMethod('isPipSupported');
      if (!isPipSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PiP not supported on this device')),
          );
        }
        return;
      }
      
      final position = _controller.value.position.inMilliseconds;
      await _pipChannel.invokeMethod('startPip', {
        'path': widget.filePath,
        'position': position.toDouble(),
      });
      
      setState(() => _isInPipMode = true);
    } on PlatformException catch (e) {
      print("Failed to start PiP: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start PiP: ${e.message}')),
        );
      }
    }
  }

  Future<void> _exitPipMode() async {
    try {
      await _pipChannel.invokeMethod('stopPip');
      setState(() => _isInPipMode = false);
    } on PlatformException catch (e) {
      print("Failed to stop PiP: ${e.message}");
    }
  }

  void _togglePip() async {
    if (_isInPipMode) {
      await _exitPipMode();
    } else {
      await _enterPipMode();
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _isPlaying = !_isPlaying;
    });
    _startControlsTimer();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text('Video Player')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video player
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            
            // Controls overlay
            if (_showControls)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent, Colors.black54],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top bar
                    AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      actions: [
                        IconButton(
                          icon: Icon(Icons.picture_in_picture),
                          onPressed: _togglePip,
                        ),
                      ],
                    ),
                    
                    // Middle controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.replay_10, color: Colors.white, size: 40),
                          onPressed: () {
                            final newPosition = _controller.value.position - Duration(seconds: 10);
                            _controller.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 50,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                        IconButton(
                          icon: Icon(Icons.forward_10, color: Colors.white, size: 40),
                          onPressed: () {
                            _controller.seekTo(_controller.value.position + Duration(seconds: 10));
                          },
                        ),
                      ],
                    ),
                    
                    // Bottom progress
                    Column(
                      children: [
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: Colors.red,
                            bufferedColor: Colors.white54,
                            backgroundColor: Colors.grey,
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_controller.value.position),
                                style: TextStyle(color: Colors.white),
                              ),
                              Text(
                                _formatDuration(_controller.value.duration),
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}