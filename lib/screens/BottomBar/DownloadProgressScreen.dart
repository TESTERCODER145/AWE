import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


enum DownloadStatus { notStarted, downloading, completed, failed }

class DownloadInfo {
  final String url;
  final String formatId;
  final String fileName;
  final String downloadId;
  double progress;
  DownloadStatus status;
  String? error;
  StreamSubscription<List<int>>? subscription;
  File? targetFile;

  DownloadInfo({
    required this.url,
    required this.formatId,
    required this.fileName,
    required this.downloadId,
    this.progress = 0.0,
    this.status = DownloadStatus.notStarted,
    this.error,
  });
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal() {
    _initializeNotifications();
  }

  final Map<String, DownloadInfo> _downloads = {};
  late Database _database;
  bool _initialized = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Map<String, DownloadInfo> get downloads => Map.unmodifiable(_downloads);

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> init() async {
    if (_initialized) return;
    _database = await openDatabase(
      path.join(await getDatabasesPath(), 'downloads.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE downloads(
          id INTEGER PRIMARY KEY, 
          title TEXT, 
          url TEXT, 
          filePath TEXT, 
          downloadDate TEXT,
          format_id TEXT
        )
      ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
          CREATE TABLE IF NOT EXISTS downloads(
            id INTEGER PRIMARY KEY, 
            title TEXT, 
            url TEXT, 
            filePath TEXT, 
            downloadDate TEXT,
            format_id TEXT
          )
        ''');
        }
      },
    );
    _initialized = true;
  }

  Future<void> startDownload({
    required String url,
    required String formatId,
    required String fileName,
  }) async {
    await init();
    final downloadId = '${url}_$formatId';

    if (_downloads.containsKey(downloadId)) return;

    final downloadInfo = DownloadInfo(
      url: url,
      formatId: formatId,
      fileName: fileName,
      downloadId: downloadId,
      status: DownloadStatus.downloading,
    );

    _downloads[downloadId] = downloadInfo;
    notifyListeners();

    try {
      if (Platform.isIOS) {
        await _downloadForIOS(downloadInfo);
      } else {
        await _downloadForAndroid(downloadInfo);
      }
    } catch (e) {
      _cleanupFailedDownload(downloadInfo);
      _updateStatus(downloadId, DownloadStatus.failed, e.toString());
      rethrow;
    }
  }

  Future<void> _downloadForIOS(DownloadInfo downloadInfo) async {
    final status = await PhotoManager.requestPermissionExtend();
    if (!status.hasAccess) {
      throw Exception('Photo library permission denied');
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${downloadInfo.fileName}');
    downloadInfo.targetFile = tempFile;

    final uri = downloadInfo.formatId == 'thumbnail'
        ? Uri.parse('https://downloadsplatform.com/api/download-thumbnail?url=${Uri.encodeComponent(downloadInfo.url)}')
        : Uri.parse('https://downloadsplatform.com/api/download?url=${Uri.encodeComponent(downloadInfo.url)}&format_id=${downloadInfo.formatId}');

    final request = http.Request('GET', uri);
    final response = await http.Client().send(request);
    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    final sink = tempFile.openWrite();
    downloadInfo.subscription = response.stream.listen(
          (List<int> chunk) {
        receivedBytes += chunk.length;
        final progress = totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
        downloadInfo.progress = progress;
        notifyListeners();
        sink.add(chunk);
      },
      onDone: () async {
        await sink.close();

        // Unified media saving for both platforms
        try {
          final File file = downloadInfo.targetFile!;

          if (downloadInfo.formatId == 'thumbnail' ||
              _isImageFile(downloadInfo.fileName)) {

            // Save to gallery using photo_manager
            final AssetEntity? entity = await _saveToGallery(file, downloadInfo.fileName);

            if (entity != null) {
              await _saveToDatabase(
                downloadInfo.fileName,
                downloadInfo.url,
                "asset://${entity.id}",
                downloadInfo.formatId,
              );
              _updateStatus(downloadInfo.downloadId, DownloadStatus.completed);
              
            } else {
              throw Exception('Failed to save to gallery');
            }
          } else {
            // Save to app directory for non-media files
            final appDocDir = await getApplicationDocumentsDirectory();
            final targetDir = Directory(path.join(appDocDir.path, 'Downloads Platform'));

            if (!await targetDir.exists()) {
              await targetDir.create(recursive: true);
            }

            final targetFile = File('${targetDir.path}/${downloadInfo.fileName}');
            await file.copy(targetFile.path);

            await _saveToDatabase(
              downloadInfo.fileName,
              downloadInfo.url,
              targetFile.path,
              downloadInfo.formatId,
            );
            _updateStatus(downloadInfo.downloadId, DownloadStatus.completed);
           
          }
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      },
      onError: (e) {
        sink.close();
        _cleanupFailedDownload(downloadInfo);
        _updateStatus(downloadInfo.downloadId, DownloadStatus.failed, e.toString());
      },
      cancelOnError: true,
      // Keep error handling same
    );
  }

  bool _isImageFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }
  Future<AssetEntity?> _saveToGallery(File file, String fileName) async {
    if (_isImageFile(fileName)) {
      return await PhotoManager.editor.saveImageWithPath(
        file.path,
        title: fileName,
        relativePath: 'Downloads Platform/',
      );
    } else {
      return await PhotoManager.editor.saveVideo(
        file,
        title: fileName,
        relativePath: 'Downloads Platform/',
      );
    }
  }
  Future<void> _downloadForAndroid(DownloadInfo downloadInfo) async {
    if (!await _requestPermissions()) {
      throw Exception('Storage permission denied');
    }

    final dir = await _getDownloadDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File('${dir.path}/${_sanitizeFileName(downloadInfo.fileName)}');
    downloadInfo.targetFile = file;

    final uri = downloadInfo.formatId == 'thumbnail'
        ? Uri.parse('https://downloadsplatform.com/api/download-thumbnail?url=${Uri.encodeComponent(downloadInfo.url)}')
        : Uri.parse('https://downloadsplatform.com/api/download?url=${Uri.encodeComponent(downloadInfo.url)}&format_id=${downloadInfo.formatId}');

    final request = http.Request('GET', uri);
    final response = await http.Client().send(request);
    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    final sink = file.openWrite();
    downloadInfo.subscription = response.stream.listen(
          (List<int> chunk) {
        receivedBytes += chunk.length;
        final progress = totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
        downloadInfo.progress = progress;
        notifyListeners();
        sink.add(chunk);
      },
      onDone: () async {
        await sink.close();
        await _saveToDatabase(downloadInfo.fileName, downloadInfo.url, file.path, downloadInfo.formatId);
        _updateStatus(downloadInfo.downloadId, DownloadStatus.completed);

        
      },
      onError: (e) {
        sink.close();
        _cleanupFailedDownload(downloadInfo);
        _updateStatus(downloadInfo.downloadId, DownloadStatus.failed, e.toString());
      },
      cancelOnError: true,
    );
  }

  Future<void> _showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'downloads_channel',
      'Downloads',
      channelDescription: 'Notifications for completed downloads',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final baseDir = Directory('/storage/emulated/0/Download');
      return Directory(path.join(baseDir.path, 'Downloads Platform'));
    } else if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return Directory(path.join(dir.path, 'Downloads Platform'));
    }
    throw UnsupportedError('Unsupported platform');
  }

  Future<void> _cleanupFailedDownload(DownloadInfo? downloadInfo) async {
    try {
      if (downloadInfo?.targetFile?.existsSync() ?? false) {
        await downloadInfo?.targetFile?.delete();
      }
    } catch (e) {
      print('Error cleaning up failed download: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        // Use manageExternalStorage only if needed
        return await Permission.manageExternalStorage.request().isGranted;
      } else if (androidInfo.version.sdkInt >= 29) {
        // No permission needed for scoped storage
        return true;
      } else {
        return await Permission.storage.request().isGranted;
      }
    }
    return true; // iOS handled elsewhere
  }

  String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[^\w\d-._]'), '_');

  Future<void> _saveToDatabase(String title, String url, String path, String formatId) async {
    try {
      await _database.insert('downloads', {
        'title': title,
        'url': url,
        'filePath': path,
        'downloadDate': DateTime.now().toIso8601String(),
        'format_id': formatId,
      });
    } catch (e) {
      print('Database save error: $e');
      rethrow;
    }
  }

  void _updateStatus(String id, DownloadStatus status, [String? error]) {
    final download = _downloads[id];
    if (download == null) return;

    download.status = status;
    download.error = error;
    // Immediate notification for UI update
    notifyListeners();

    if (status == DownloadStatus.completed || status == DownloadStatus.failed) {
      Future.delayed(Duration(milliseconds: 500), () {
        _downloads.remove(id);
        notifyListeners();
      });
    }
  }

  void cancelDownload(String id) {
    final download = _downloads[id];
    if (download != null) {
      download.subscription?.cancel();
      _cleanupFailedDownload(download);
      _downloads.remove(id);
      notifyListeners();
    }
  }

  Future<void> clearAllDownloads() async {
    for (final download in _downloads.values) {
      cancelDownload(download.downloadId);
    }
    _downloads.clear();
    notifyListeners();
  }
}