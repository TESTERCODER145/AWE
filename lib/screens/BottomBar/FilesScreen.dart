import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crypto/crypto.dart';
// For Android
import 'package:floating/floating.dart' as Float;
// For iOS  
import 'package:fl_pip/fl_pip.dart' as flpip;
import 'package:pip_view/pip_view.dart';
import 'package:audio_session/audio_session.dart';
import 'package:downloadsplatform/screens/BottomBar/PipHandler.dart';


import 'dart:convert';

class ThumbnailCache {
  static final Map<String, ImageProvider> _cache = {};
  static const int MAX_CACHE_SIZE = 50;

  static ImageProvider? getThumbnail(String path) => _cache[path];

  static void addThumbnail(String path, ImageProvider image) {
    if (_cache.length >= MAX_CACHE_SIZE) {
      _cache.remove(_cache.keys.first);
    }
    _cache[path] = image;
  }

  static void clearCache() {
    _cache.clear();
  }
}

class ImageViewer extends StatelessWidget {
  final String filePath;
  const ImageViewer({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              try {
                await Share.shareXFiles([XFile(filePath)]);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to share')),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        child: PhotoView(
          imageProvider: FileImage(File(filePath)),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
      ),
    );
  }
}

// Native Thumbnail Generator (platform channel implementation)
class NativeThumbnail {
  static const MethodChannel _channel = MethodChannel('native_thumbnail');

  static Future<String?> generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final hash = md5.convert(utf8.encode(videoPath)).toString();
      final thumbnailPath =
          '${tempDir.path}/thumb_${hash}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await _channel.invokeMethod('generateThumbnail', {
        'videoPath': videoPath,
        'thumbnailPath': thumbnailPath,
        'maxWidth': 200,
        'quality': 80,
      });

      return result as String?;
    } catch (e) {
      print('Thumbnail generation failed: $e');
      return null;
    }
  }
}

enum SortOption {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
}

class FileManager extends StatefulWidget {
  @override
  _FileManagerState createState() => _FileManagerState();
}

class _FileManagerState extends State<FileManager> {
  List<FileSystemEntity> files = [];
  Directory? currentDirectory;
  String selectedFilter = 'الكل';
  SortOption currentSort = SortOption.dateDesc;
  final Map<String, List<String>> filters = {
    'الكل': [],
    'فيديو': ['mp4', 'mov', 'avi'],
    'صوت': ['mp3', 'wav', 'aac', 'm4a'],
    'صور': ['jpg', 'jpeg', 'png', 'gif'],
    'مستندات': ['pdf', 'doc', 'docx', 'txt'],
  };
  String baseDownloadPath = '';

  // Map to store VideoPlayerController instances for thumbnail generation
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _cleanupThumbnails();
  }

  Future<void> _cleanupThumbnails() async {
    final tempDir = await getTemporaryDirectory();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    tempDir
        .listSync()
        .where((f) => f.statSync().modified.isBefore(cutoff))
        .forEach((f) => f.deleteSync());
  }

  @override
  void dispose() {
    // Dispose all video controllers when the widget is disposed
    
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
  
    super.dispose();
  }

  Widget _buildFileThumbnail(FileSystemEntity file, String ext, bool isDir) {
    if (isDir) return const Icon(Icons.folder, color: Colors.amber, size: 40);

    return FutureBuilder<Widget>(
      future: _getThumbnailWidget(file, ext),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _getFileIcon(ext, false);
        }
        return snapshot.data ?? _getFileIcon(ext, false);
      },
    );
  }

  Future<Widget> _getThumbnailWidget(FileSystemEntity file, String ext) async {
    final cachedThumb = await ThumbnailCache.getThumbnail(file.path);
    if (cachedThumb != null) {
      return Image(
          image: cachedThumb, width: 40, height: 40, fit: BoxFit.cover);
    }

    if (filters['صور']!.contains(ext)) {
      return _loadImageThumbnail(file);
    }

    if (filters['فيديو']!.contains(ext)) {
      return _createVideoThumbnail(file.path);
    }

    return _getFileIcon(ext, false);
  }

  Future<Widget> _loadImageThumbnail(FileSystemEntity file) async {
    try {
      final image = FileImage(File(file.path));
      final completer = Completer<ImageInfo>();
      image.resolve(ImageConfiguration()).addListener(
          ImageStreamListener((info, _) => completer.complete(info)));
      await completer.future;
      ThumbnailCache.addThumbnail(file.path, image);
      return Image(image: image, width: 40, height: 40, fit: BoxFit.cover);
    } catch (e) {
      return _getFileIcon('', false);
    }
  }

  Widget _loadingPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      color: Colors.grey[300],
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Future<Widget> _createVideoThumbnail(String videoPath) async {
    try {
      final cachedThumb = await ThumbnailCache.getThumbnail(videoPath);
      if (cachedThumb != null) {
        return Image(
            image: cachedThumb, width: 40, height: 40, fit: BoxFit.cover);
      }

      final tempDir = await getTemporaryDirectory();
      final thumbnailPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Generate thumbnail using platform channels
      final generatedPath = await NativeThumbnail.generateThumbnail(videoPath);

      if (generatedPath != null) {
        // For iOS: Compress and optimize thumbnail
        if (Platform.isIOS) {
          final compressedPath = await FlutterImageCompress.compressAndGetFile(
            generatedPath,
            thumbnailPath,
            quality: 80,
            minWidth: 200,
            minHeight: 200,
          );

          if (compressedPath != null) {
            final imageProvider = FileImage(File(compressedPath.path));
            ThumbnailCache.addThumbnail(videoPath, imageProvider);
            return Image(
                image: imageProvider, width: 40, height: 40, fit: BoxFit.cover);
          }
        }

        // For Android: Use directly generated thumbnail
        final imageProvider = FileImage(File(generatedPath));
        ThumbnailCache.addThumbnail(videoPath, imageProvider);
        return Image(
            image: imageProvider, width: 40, height: 40, fit: BoxFit.cover);
      }

      return const Icon(Icons.video_file, size: 40);
    } catch (e) {
      return const Icon(Icons.video_file, size: 40);
    }
  }

  void _cleanupVideoControllers() {
    _videoControllers.removeWhere((path, controller) {
      if (!files.any((file) => file.path == path)) {
        controller.dispose();
        return true;
      }
      return false;
    });
  }

  Future<bool> _isHuaweiDevice() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.manufacturer.toLowerCase().contains('huawei');
  }

  Future<void> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final isHuawei = await _isHuaweiDevice();
        if (isHuawei) {
          // Handle Huawei-specific permission request
          final status = await Permission.storage.request();
          if (status.isGranted) {
            // Continue with directory setup
            final baseDir = Directory('/storage/emulated/0/Download');
            currentDirectory =
                Directory(path.join(baseDir.path, 'Downloads Platform'));
            baseDownloadPath = currentDirectory!.path;

            if (!await currentDirectory!.exists()) {
              await currentDirectory!.create(recursive: true);
            }

            getFiles();
          } else {
            // Handle permission denial
            print('Storage permission denied');
          }
        } else {
          // For non-Huawei Android devices
          final status = await Permission.manageExternalStorage.request();
          if (status.isGranted) {
            final baseDir = Directory('/storage/emulated/0/Download');
            currentDirectory =
                Directory(path.join(baseDir.path, 'Downloads Platform'));
            baseDownloadPath = currentDirectory!.path;

            if (!await currentDirectory!.exists()) {
              await currentDirectory!.create(recursive: true);
            }

            getFiles();
          }
        }
      } else if (Platform.isIOS) {
        // iOS code remains the same
        final dir = await getApplicationDocumentsDirectory();
        currentDirectory = Directory(path.join(dir.path, 'Downloads Platform'));
        baseDownloadPath = currentDirectory!.path;

        if (!await currentDirectory!.exists()) {
          await currentDirectory!.create(recursive: true);
        }

        getFiles();
      }
    } catch (e) {
      print('Error initializing directory: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في تهيئة المجلد')),
      );
    }
  }

  Future<void> getFiles() async {
    if (currentDirectory == null || !currentDirectory!.existsSync()) return;

    final fileList = currentDirectory!.listSync().where((file) {
      if (FileSystemEntity.isDirectorySync(file.path)) return true;
      final ext = file.path.split('.').last.toLowerCase();
      return filters.values.expand((e) => e).contains(ext);
    }).toList();

    setState(() {
      files = fileList;
    });

    // Pre-load video thumbnails for better performance
    // for (var file in fileList) {
    //   if (!FileSystemEntity.isDirectorySync(file.path)) {
    //     final ext = file.path.split('.').last.toLowerCase();
    //     if (filters['فيديو']!.contains(ext)) {
    //       _createVideoThumbnail(file.path);
    //     }
    //   }
    // }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  List<FileSystemEntity> filterFiles(List<FileSystemEntity> files) {
    if (selectedFilter == 'الكل') return files;
    return files.where((file) {
      if (selectedFilter == 'مجلدات')
        return FileSystemEntity.isDirectorySync(file.path);
      final ext = file.path.split('.').last.toLowerCase();
      return filters[selectedFilter]?.contains(ext) ?? false;
    }).toList();
  }

  Future<void> _shareFile(FileSystemEntity file) async {
    try {
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في المشاركة')),
      );
    }
  }

  List<FileSystemEntity> sortFiles(List<FileSystemEntity> files) {
    List<FileSystemEntity> dirs = [];
    List<FileSystemEntity> filesOnly = [];

    for (var file in files) {
      if (FileSystemEntity.isDirectorySync(file.path)) {
        dirs.add(file);
      } else {
        filesOnly.add(file);
      }
    }

    void sortList(List<FileSystemEntity> list) {
      switch (currentSort) {
        case SortOption.nameAsc:
          list.sort((a, b) => a.path
              .split('/')
              .last
              .toLowerCase()
              .compareTo(b.path.split('/').last.toLowerCase()));
          break;
        case SortOption.nameDesc:
          list.sort((a, b) => b.path
              .split('/')
              .last
              .toLowerCase()
              .compareTo(a.path.split('/').last.toLowerCase()));
          break;
        case SortOption.dateAsc:
          list.sort(
              (a, b) => a.statSync().modified.compareTo(b.statSync().modified));
          break;
        case SortOption.dateDesc:
          list.sort(
              (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
          break;
      }
    }

    sortList(dirs);
    sortList(filesOnly);

    return [...dirs, ...filesOnly];
  }

  String _getSortOptionText(SortOption option) {
    switch (option) {
      case SortOption.nameAsc:
        return 'الاسم من أ إلى ي';
      case SortOption.nameDesc:
        return 'الاسم من ي إلى أ';
      case SortOption.dateAsc:
        return 'القديم أولاً';
      case SortOption.dateDesc:
        return 'الجديد أولاً';
    }
  }

  Widget _buildSortDropdown() {
    return DropdownButton<SortOption>(
      value: currentSort,
      icon: Icon(Icons.sort, color: Colors.black),
      underline: SizedBox(),
      onChanged: (SortOption? newValue) {
        setState(() => currentSort = newValue!);
      },
      items: SortOption.values.map((option) {
        return DropdownMenuItem<SortOption>(
          value: option,
          child: Text(_getSortOptionText(option)),
        );
      }).toList(),
    );
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    if (await file.exists()) {
      await file.delete();
      getFiles();
    }
  }

  void _navigateToDirectory(Directory directory) {
    setState(() {
      currentDirectory = directory;
    });
    getFiles();
  }

  void _navigateBack() async {
    if (currentDirectory != null &&
        currentDirectory!.path != baseDownloadPath) {
      setState(() {
        currentDirectory = currentDirectory!.parent;
      });
      getFiles();
    }
  }

  void openFile(FileSystemEntity file) async {
    final ext = file.path.split('.').last.toLowerCase();

    try {
      if (filters['صور']!.contains(ext)) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ImageViewer(filePath: file.path)));
      } else if (filters['صوت']!.contains(ext)) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AudioPlayerScreen(filePath: file.path)));
      } else if (filters['فيديو']!.contains(ext)) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(filePath: file.path)));
      } else if (ext == 'pdf') {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PDFViewerScreen(filePath: file.path)));
      } else {
        throw Exception('Unsupported file type');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يمكن فتح هذا النوع من الملفات')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(child: _buildFileList()),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.keys
            .map((key) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(key),
                    selected: selectedFilter == key,
                    onSelected: (v) =>
                        setState(() => selectedFilter = v ? key : 'الكل'),
                    selectedColor: Colors.blue[100],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildFileList() {
    final filteredFiles = filterFiles(files);
    final sortedFiles = sortFiles(filteredFiles);

    return ListView.builder(
      itemCount: sortedFiles.length,
      itemBuilder: (context, index) {
        final file = sortedFiles[index];
        final isDir = FileSystemEntity.isDirectorySync(file.path);
        final ext = file.path.split('.').last.toLowerCase();

        return ListTile(
          leading: _buildFileThumbnail(file, ext, isDir),
          title: Text(
            file.path.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: isDir
              ? Text('مجلد')
              : Text(_formatFileSize(File(file.path).lengthSync())),
          trailing: isDir ? null : _fileActions(file),
          onTap: () => isDir
              ? _navigateToDirectory(Directory(file.path))
              : openFile(file),
        );
      },
    );
  }

  // Instead of storing controllers in a map, generate thumbnails and dispose immediately
  Future<void> generateAndCacheThumbnail(String videoPath) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();

      if (controller.value.isInitialized) {
        // Here you could use a package like screenshot or flutter_image to
        // capture a frame and store it as an actual image in the cache

        // For now, just store the file path to indicate it's been processed
        ThumbnailCache.addThumbnail(videoPath, FileImage(File(videoPath)));
      }

      controller.dispose();
    } catch (e) {
      print("Error generating thumbnail: $e");
    }
  }

  Widget _fileActions(FileSystemEntity file) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.share, size: 20),
          onPressed: () => _shareFile(file),
        ),
        IconButton(
          icon: Icon(Icons.delete, size: 20, color: Colors.red),
          onPressed: () => _deleteFile(file),
        ),
      ],
    );
  }

  Widget _getFileIcon(String ext, bool isDir) {
    if (isDir) return Icon(Icons.folder, color: Colors.amber);
    final colors = {
      'صور': Colors.red,
      'فيديو': Colors.purple,
      'صوت': Colors.green,
      'مستندات': Colors.blue,
    };
    final iconData = {
      'صور': Icons.image,
      'فيديو': Icons.video_file,
      'صوت': Icons.audiotrack,
      'مستندات': Icons.description,
    };

    for (var entry in filters.entries) {
      if (entry.value.contains(ext)) {
        return Icon(iconData[entry.key], color: colors[entry.key]);
      }
    }
    return Icon(Icons.insert_drive_file, color: Colors.grey);
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String filePath;

  const VideoPlayerScreen({required this.filePath});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isInPipMode = false;
  bool _showControls = true;
  bool _isFullScreen = false;
  Timer? _controlsTimer;
  bool _isAdjustingVolume = false;
  bool _isAdjustingBrightness = false;
  double _initialVolume = 0;
  double _initialBrightness = 0.0;
  double _currentVolumeLevel = 0;
  bool _isMuted = false;
  double _currentBrightnessLevel = 0.0;
  bool _showVolumeOverlay = false;
  bool _showBrightnessOverlay = false;
  Timer? _overlayTimer;
  late final VolumeController _volumeController;
  late final StreamSubscription<double>? _volumeSubscription;
  GlobalKey _betterPlayerKey = GlobalKey();
  static const _pipChannel = MethodChannel('pip_channel');
  bool _showPip = false;
Offset _pipPosition = Offset(20, 20);
double _pipSize = 200;
// Add this global variable at the top of your file
bool _globalPipActive = false;
Offset _globalPipPosition = Offset(20, 20);
double _globalPipSize = 300; // Increased from 200 to 300

void _togglePip() async {
 
    // Android: Existing native PiP logic
    if (_globalPipActive) {
      await _exitPipMode();
    } else {
      await _enterPipMode();
    }
    setState(() => _globalPipActive = !_globalPipActive);
  
}
// Add these handler methods
void _toggleFullScreenFromPip() {
  setState(() {
    _globalPipActive = false;
    _isFullScreen = true;
  });
  _toggleFullScreen();
}


Future<void> _initAudioSession() async {
  final session = await AudioSession.instance;
  
  if (Platform.isAndroid) {
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: 
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  } else if (Platform.isIOS) {
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: 
          AVAudioSessionCategoryOptions.allowBluetooth ,
      
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
    ));
  }
}

Widget _buildPipOverlay() {
  return Positioned(
    left: _pipPosition.dx,
    top: _pipPosition.dy,
    child: GestureDetector(
      onPanUpdate: (details) {
        setState(() => _pipPosition += details.delta);
      },
      child: Container(
        width: _pipSize,
        height: _pipSize * 9 / 16,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              spreadRadius: 2,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Video Content
              VideoPlayer(_controller),
              
              // Control Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  color: Colors.black54,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Full Screen Button
                      IconButton(
                        icon: Icon(Icons.fullscreen, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showPip = false;
                            if (!_isFullScreen) _toggleFullScreen();
                            if (!_isPlaying) _togglePlayPause();
                          });
                        },
                      ),
                      
                      // Play/Pause Button
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      
                      // Close Button
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showPip = false;
                            _controller.pause();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
Widget _buildGlobalPipOverlay() {
  if (!_globalPipActive) return const SizedBox.shrink();

  return Positioned(
    left: _globalPipPosition.dx,
    top: _globalPipPosition.dy,
    child: GestureDetector(
      onPanUpdate: (details) {
        setState(() => _globalPipPosition += details.delta);
      },
      child: Container(
        width: _globalPipSize,
        height: _globalPipSize * 9 / 16,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 12,
              spreadRadius: 4,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              VideoPlayer(_controller),
              _buildPipControls(),
            ],
          ),
        ),
      ),
    ),
  );
}
// Separate control building
Widget _buildPipControls() {
  return Positioned.fill(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top controls
        Container(
          color: Colors.black54,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: _closePip,
              ),
            ],
          ),
        ),
        
        // Center play controls
        Expanded(
          child: Center(
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 42,
              ),
              onPressed: _togglePlayPause,
            ),
          ),
        ),
        
        // Bottom controls
        Container(
          color: Colors.black54,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.replay_10, color: Colors.white, size: 28),
                onPressed: _skipBackward,
              ),
              IconButton(
                icon: Icon(Icons.fullscreen, color: Colors.white, size: 28),
                onPressed: _toggleFullScreenFromPip,
              ),
              IconButton(
                icon: Icon(Icons.forward_10, color: Colors.white, size: 28),
                onPressed: _skipForward,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


void _closePip() {
  setState(() {
    _globalPipActive = false;
    if (_isPlaying) _togglePlayPause();
  });
  if (Platform.isIOS) {
    _pipChannel.invokeMethod('stopPip');
  }
}



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isIOS) {
    _initializePlayer();
  } 
   _initializeVideoPlayer();
    _initVolumeListener();
    
    // Make sure overlays are hidden at start
    _showVolumeOverlay = false;
    _showBrightnessOverlay = false;
  }


void _initializePlayer() {
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
void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _initVolumeListener() {
    // Initialize the volume controller
    // VolumeController().showSystemUI = false;
    // Get initial volume
    _volumeController = VolumeController.instance;

    // Listen to system volume change
    _volumeSubscription = _volumeController.addListener((volume) {
      setState(() => _initialVolume = volume);
    }, fetchInitialVolume: true);
    _volumeController
        .isMuted()
        .then((isMuted) => setState(() => _isMuted = isMuted));
  }

  void _handleVerticalDragStart(DragStartDetails details) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;

    if (dx < screenWidth / 2) {
      // Volume control
      try {
        _initialVolume = await _volumeController.getVolume();
        setState(() {
          _isAdjustingVolume = true;
          _currentVolumeLevel = _initialVolume;
          _showVolumeOverlay = true;
        });
        _cancelOverlayTimer();
      } catch (e) {
        print("Error getting volume: $e");
      }
    } else {
      // Brightness control
      try {
        _initialBrightness = await ScreenBrightness().current;
        setState(() {
          _isAdjustingBrightness = true;
          _currentBrightnessLevel = _initialBrightness;
          _showBrightnessOverlay = true;
        });
        _cancelOverlayTimer();
      } catch (e) {
        print("Error getting brightness: $e");
      }
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) async {
    if (_isAdjustingVolume) {
      double delta = details.delta.dy;
      double newVolume = _initialVolume - (delta / 200);
      newVolume = newVolume.clamp(0.0, 1.0);
      try {
        await _volumeController.setVolume(newVolume);
        setState(() {
          _currentVolumeLevel = newVolume;
          _showVolumeOverlay = true;
        });
        _cancelOverlayTimer();
        _startOverlayTimer(); // Start the timer after each adjustment
      } catch (e) {
        print("Error setting volume: $e");
      }
    } else if (_isAdjustingBrightness) {
      double delta = details.delta.dy;
      double newBrightness = _initialBrightness - (delta / 200);
      newBrightness = newBrightness.clamp(0.0, 1.0);
      try {
        await ScreenBrightness().setScreenBrightness(newBrightness);
        setState(() {
          _currentBrightnessLevel = newBrightness;
          _showBrightnessOverlay = true;
        });
        _cancelOverlayTimer();
        _startOverlayTimer(); // Start the timer after each adjustment
      } catch (e) {
        print("Error setting brightness: $e");
      }
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isAdjustingVolume = false;
      _isAdjustingBrightness = false;
    });
    // Start the timer to hide overlays after 1 second
    _startOverlayTimer();
  }

  void _cancelOverlayTimer() {
    _overlayTimer?.cancel();
  }

  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showVolumeOverlay = false;
          _showBrightnessOverlay = false;
        });
      }
    });
  }

  void _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.file(File(widget.filePath));
      // Add this line to load the first frame immediately
      await _controller.setLooping(false);

      _controller.initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            // Auto-play when initialized
            _controller.play();
            _isPlaying = true;
          });

          // Start the controls auto-hide timer
          _controlsTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showControls = false);
          });
        }
      }).catchError((error) {
        print("Video initialization error: $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في تشغيل الفيديو')),
          );
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      print("Error creating controller: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تشغيل الفيديو')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    //  _betterPlayerController.dispose();
    _controlsTimer?.cancel();
    _controller.dispose();
    _overlayTimer?.cancel();
    // Remove volume listener
    _volumeSubscription?.cancel();

    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildVolumeOverlay() {
    return Positioned(
      left: 20,
      top: MediaQuery.of(context).size.height / 2 - 40,
      child: AnimatedOpacity(
        opacity: _showVolumeOverlay ? 1 : 0,
        duration: Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                _currentVolumeLevel <= 0
                    ? Icons.volume_off
                    : _currentVolumeLevel < 0.5
                        ? Icons.volume_down
                        : Icons.volume_up,
                color: Colors.white,
                size: 40,
              ),
              SizedBox(height: 8),
              Text(
                '${(_currentVolumeLevel * 100).round()}%',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrightnessOverlay() {
    return Positioned(
      right: 20,
      top: MediaQuery.of(context).size.height / 2 - 40,
      child: AnimatedOpacity(
        opacity: _showBrightnessOverlay ? 1 : 0,
        duration: Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                Icons.brightness_5,
                color: Colors.white,
                size: 40,
              ),
              SizedBox(height: 8),
              Text(
                '${(_currentBrightnessLevel * 100).round()}%',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, VideoPlayerValue value, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(value.position),
                style: TextStyle(color: Colors.white),
              ),
              Text(
                _formatDuration(value.duration),
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _controlsTimer?.cancel();
    if (_showControls) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
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
    
  }
 

  void _skipForward() {
    final currentPosition = _controller.value.position;
    final newPosition = currentPosition + const Duration(seconds: 10);
    _controller.seekTo(newPosition);
  }

  void _skipBackward() {
    final currentPosition = _controller.value.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    _controller
        .seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }
  
void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // Hide status bar in fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      // Show status bar
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
}

  Widget _buildControls() {
    return AnimatedOpacity(
      opacity: _showControls ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent, Colors.black54],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isFullScreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFullScreen,
                      ),
                      IconButton(
                          icon: const Icon(Icons.picture_in_picture),
                          onPressed: _togglePip,
                          color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
            Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10,
                          size: 40, color: Colors.white),
                      onPressed:_skipBackward,
                    ),
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 50,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10,
                          size: 40, color: Colors.white),
                      onPressed:_skipForward,
                    ),
                  ],
                ),
              ],
            )),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.red,
                      bufferedColor: Colors.white54,
                      backgroundColor: Colors.grey,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  _buildTimeDisplay(),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // User is leaving the app, enter PiP if not already in PiP
      if (!_isInPipMode && _isInitialized && _isPlaying) {
        
        _enterPipMode();

      }
       if (Platform.isIOS && _isPlaying) {
      _togglePip(); // Automatically enter PiP when app backgrounds
    }
    } else if (state == AppLifecycleState.resumed && _isInPipMode) {
      // User returned to the app while in PiP, exit PiP
      _exitPipMode();
    }
  }

  Future<void> _enterPipMode() async {
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid) {
        final floating = Float.Floating();
        final isAvailable = await floating.isPipAvailable;

        if (!isAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PiP not available on this device')),
          );
          return;
        }

        final status = await floating.enable(Float.ImmediatePiP(
          aspectRatio: Float.Rational(
            _controller.value.size.width.toInt(),
            _controller.value.size.height.toInt(),
          ),
          sourceRectHint: Rectangle<int>(
            0,
            0,
            _controller.value.size.width.toInt(),
            _controller.value.size.height.toInt(),
          ),
        ));

        if (status == Float.PiPStatus.enabled) {
          setState(() => _globalPipActive = true);
        }
      } else if (Platform.isIOS) {
        // iOS implementation using flutter_in_app_pip
        // Create PiP widget with Android-style controls
      //  try {
      // bool isPipSupported = await _pipChannel.invokeMethod('isPipSupported');
      // if (!isPipSupported) {
      //   if (mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(content: Text('PiP not supported on this device')),
      //     );
      //   }
      //   return;
      // }
      
     bool isSupported = await PiPService.isPiPSupported();
                if (isSupported) {
                  await PiPService.startPiP(videoFilePath, 0);
                  setState(() => _globalPipActive = true);
                } else {
                  print("PiP not supported on this device.");
                }
      //  final isAvailable = await flpip.FlPiP().isAvailable;
      //   bool? isSupported = await _pipChannel.invokeMethod<bool>('isPipSupported');
      //     if (isSupported != true) {
      //   if (mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('PiP not supported on this device')),
      //     );
      //   }
      //   return;
      // }

      //         if (isAvailable) {
      //           // Enable PiP with iOS configuration
      //           await flpip.FlPiP().enable(
      //             ios: flpip.FlPiPiOSConfig(
      //               // Point to your actual video file in assets
      //               videoPath: widget.filePath,
      //               // Use null for your own project assets
      //               packageName: null,
      //               createNewEngine: true,
      //               // Enable playback controls
      //               enableControls: true,
      //               // Enable playback speed controls
      //               enablePlayback: true,
      //               // Continue PiP when app is in background
      //               enabledWhenBackground: true,
      //             ),
      //           );
                
      //           // Put app in background mode to show PiP
      //           await flpip.FlPiP().toggle(flpip.AppState.background);
      //         } else {
      //           ScaffoldMessenger.of(context).showSnackBar(
      //             const SnackBar(content: Text('PiP is not available on this device')),
      //           );
      //         }
      
      
    } 

       
      } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PiP error: ${e.toString()}')),
      );
    }
  }

  Future<void> _exitPipMode() async {
    if (_globalPipActive) {
      try {
        if (Platform.isIOS) {
          // iOS implementation using flutter_in_app_pip
          try {
     await PiPService.stopPiP();

        setState(() => _globalPipActive = false);
      } catch (e) {
        print('Error exiting PiP mode: $e');
      }
    }
  }
  Widget _buildVideoPlayer() {
  return Center(
    child: AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    ),
  );
}

 @override
Widget build(BuildContext context) {
  if (!_isInitialized) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Player'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  return WillPopScope(
    onWillPop: () async {
      if (_isFullScreen) {
        _toggleFullScreen();
        return false;
      }
      return true;
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!_globalPipActive)
            GestureDetector(
              onTap: _toggleControls,
              onVerticalDragStart: _handleVerticalDragStart,
              onVerticalDragUpdate: _handleVerticalDragUpdate,
              onVerticalDragEnd: _handleVerticalDragEnd,
              child: _isFullScreen
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width:  _controller.value.size.width,
                          height:  _controller.value.size.height,
                          child:  VideoPlayer(_controller),
                        ),
                      ),
                    )
                  : Center(
                      child: AspectRatio(
                        aspectRatio:  _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
            ),
          // PiP Overlay (shown when active)
          if(_globalPipActive) _buildGlobalPipOverlay(),
          if (_showPip) _buildPipOverlay(),
          if (_showControls && !_globalPipActive) _buildControls(),
          if (_showVolumeOverlay) _buildVolumeOverlay(),
          if (_showBrightnessOverlay) _buildBrightnessOverlay(),
        ],
      ),
    ),
  );
}

}

// Add this in main.dart or a separate file
class PipOverlay extends StatelessWidget {
  const PipOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: GestureDetector(
          onTap: () => FlutterOverlayWindow.closeOverlay(),
          child: const Center(
            child: Text('PiP Overlay Content'),
          ),
        ),
      ),
    );
  }
}

// Enhanced Audio Player
class AudioPlayerScreen extends StatefulWidget {
  final String filePath;
  final String? nextFilePath;
  final String? previousFilePath;
  final Function()? onNext;
  final Function()? onPrevious;

  AudioPlayerScreen({
    required this.filePath,
    this.nextFilePath,
    this.previousFilePath,
    this.onNext,
    this.onPrevious,
  });

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  double _volume = 1.0;
  double _speed = 1.0;
  bool _isLooping = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _player = AudioPlayer();
      await _player.setFilePath(widget.filePath);
      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });
    } catch (e) {
      print("Error initializing audio player: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تشغيل الملف الصوتي: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مشغل الصوت')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // File info
            _buildFileInfo(),

            SizedBox(height: 32),

            // Progress bar
            _buildProgressBar(),

            SizedBox(height: 8),

            // Time display
            _buildTimeDisplay(),

            SizedBox(height: 32),

            // Main playback controls
            _buildPlaybackControls(),

            SizedBox(height: 24),

            // Additional controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Speed control
                _buildSpeedControl(),

                // Loop control
                IconButton(
                  icon: Icon(_isLooping ? Icons.repeat_one : Icons.repeat),
                  onPressed: () {
                    setState(() => _isLooping = !_isLooping);
                    _player
                        .setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
                  },
                ),
              ],
            ),

            SizedBox(height: 24),

            // Volume control slider
            _buildVolumeControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfo() {
    return Text(
      widget.filePath.split('/').last,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: _player.durationStream,
          builder: (context, snapshot) {
            final duration = snapshot.data ?? Duration.zero;
            return Slider(
              value: position.inMilliseconds
                  .toDouble()
                  .clamp(0, duration.inMilliseconds.toDouble()),
              max: duration.inMilliseconds.toDouble(),
              onChanged: (value) {
                _player.seek(Duration(milliseconds: value.toInt()));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTimeDisplay() {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: _player.durationStream,
          builder: (context, snapshot) {
            final duration = snapshot.data ?? Duration.zero;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position)),
                Text(_formatDuration(duration)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.previousFilePath != null)
          IconButton(
            icon: Icon(Icons.skip_previous, size: 40),
            onPressed: widget.onPrevious,
          ),
        IconButton(
          icon: Icon(Icons.replay_10, size: 40),
          onPressed: () => _player.seek(
            Duration(
                seconds: (_player.position.inSeconds - 10)
                    .clamp(0, double.infinity)
                    .toInt()),
          ),
        ),
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 50),
          onPressed: () async {
            if (_isPlaying) {
              await _player.pause();
            } else {
              await _player.play();
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.forward_10, size: 40),
          onPressed: () => _player.seek(
            Duration(seconds: _player.position.inSeconds + 10),
          ),
        ),
        if (widget.nextFilePath != null)
          IconButton(
            icon: Icon(Icons.skip_next, size: 40),
            onPressed: widget.onNext,
          ),
      ],
    );
  }

  Widget _buildVolumeControl() {
    return Row(
      children: [
        Icon(Icons.volume_down),
        Expanded(
          child: Slider(
            value: _volume,
            onChanged: (value) {
              setState(() => _volume = value);
              _player.setVolume(value);
            },
          ),
        ),
        Icon(Icons.volume_up),
      ],
    );
  }

  Widget _buildSpeedControl() {
    return DropdownButton<double>(
      value: _speed,
      items: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
        return DropdownMenuItem(
          value: speed,
          child: Text('${speed}x'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _speed = value);
          _player.setSpeed(value);
        }
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

class PDFViewerScreen extends StatelessWidget {
  final String filePath;
  PDFViewerScreen({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('عرض PDF')),
      body: PDFView(filePath: filePath),
    );
  }
}