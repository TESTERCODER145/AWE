import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:downloadsplatform/Models/StoragePermissionHandler.dart';
import 'package:downloadsplatform/Models/auth_provider.dart';
import 'package:downloadsplatform/screens/BottomBar/DownloadProgressScreen.dart';
import 'package:downloadsplatform/screens/BottomBar/HistoryDownload.dart';

class MainContent extends StatefulWidget {
  final Function(int) onDownloadComplete;
  const MainContent({Key? key, required this.onDownloadComplete}) : super(key: key);

  @override
  State<MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<MainContent> {
  final TextEditingController _urlController = TextEditingController();
  Map<String, dynamic>? _mediaInfo;
  bool _isLoading = false;
  String? _errorMessage;

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _fetchMediaInfo() async {
    if (_urlController.text.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال الرابط');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _mediaInfo = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://downloadsplatform.com/api/info'),
        body: json.encode({'url': _urlController.text}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() => _mediaInfo = json.decode(response.body));
      } else {
        setState(() => _errorMessage = json.decode(response.body)["error"]);
      }
    } catch (e) {
      setState(() => _errorMessage = 'خطأ في الاتصال ');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _requestIOSPhotoLibraryPermission() async {
    final status = await PhotoManager.requestPermissionExtend();
    return status.isAuth;
  }

  void _showIOSPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('الإذن مطلوب'),
        content: Text('يحتاج التطبيق إلى إذن الوصول إلى مكتبة الصور لحفظ الملفات'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  void _showAndroidPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('الإذن مطلوب'),
        content: Text('الرجاء تمكين إذن التخزين'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload(dynamic item, {bool isImage = false}) async {
    bool hasPermission = false;

    // Check platform-specific permissions
    if (Platform.isIOS) {
      hasPermission = await _requestIOSPhotoLibraryPermission();
      if (!hasPermission) {
        _showIOSPermissionDialog();
        return;
      }
    } else {
      hasPermission = await StoragePermissionHandler.requestStoragePermission();
      if (!hasPermission) {
        _showAndroidPermissionDialog();
        return;
      }
    }

    final downloadManager = Provider.of<DownloadManager>(context, listen: false);
    final downloadId = isImage
        ? 'thumbnail-${item['url']}'
        : '${_urlController.text}-${item['format_id']}';

    try {
      // Show confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم اضافة الرابط في التحميلات'),
          duration: Duration(seconds: 2),
        ),
      );

      if (isImage) {
        final imageUrl = item['url'];
        await downloadManager.startDownload(
          url: imageUrl,
          formatId: 'thumbnail',
          fileName: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      } else {
        await downloadManager.startDownload(
          url: _urlController.text,
          formatId: item['format_id'],
          fileName: '${_mediaInfo!['title'].length > 20 ? _mediaInfo!['title'].substring(0, 20) : _mediaInfo!['title']}.${item['ext']}',
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في التحميل'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDownloadOptions() {
    if (_mediaInfo == null) return Container();

    if (_mediaInfo!['isGallery'] == true) {
      final mediaItems = (_mediaInfo!['media'] as List).cast<Map<String, dynamic>>();
      return _buildScrollableGalleryGrid(mediaItems);
    }

    return _buildScrollableMediaFormats();
  }

  Widget _buildScrollableGalleryGrid(List<Map<String, dynamic>> mediaItems) {
    return Container(
      height: 400, // Set an appropriate fixed height
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('الصور المتاحة:'),
                SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: mediaItems.length,
                  itemBuilder: (context, index) => _buildGalleryItem(mediaItems[index]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableMediaFormats() {
    List<Map<String, dynamic>> formats = [];

    // Process audio formats
    if (_mediaInfo!['audio_formats'] != null) {
      final audioFormats = (_mediaInfo!['audio_formats'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .take(3)
          .toList();
      formats.addAll(audioFormats);
    }

    // Process video formats
    if (_mediaInfo!['video_formats'] != null) {
      final videoFormats = (_mediaInfo!['video_formats'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .take(3)
          .toList();
      formats.addAll(videoFormats);
    }

    return Container(
      height: 400, // Set an appropriate fixed height
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('خيارات التحميل:'),
                SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: formats.length,
                  itemBuilder: (context, index) => _buildFormatItem(formats[index]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) => Directionality(
    textDirection: TextDirection.rtl,
    child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );

  Widget _buildGalleryItem(Map<String, dynamic> media) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _startDownload(media, isImage: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 16/9,
                child: Image.network(
                  media['thumbnail'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                  loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('تحميل الصورة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatItem(Map<String, dynamic> format) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _startDownload(format),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 16/9,
                child: Image.network(
                  _mediaInfo!['thumbnail'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                  loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      format['ext'] == 'mp4' ? 'تحميل فيديو' : 'تحميل ملف صوتي',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),

                  Text('الحجم: ${_formatFileSize(format['filesize'] ?? 0)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: authProvider.isAuthenticated
            ? Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            '${authProvider.currentUser.userData!['firstName']} ${authProvider.currentUser.userData!['lastName']}',
          ),
        )
            : Text(""),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUrlInput(),
            if (_errorMessage != null) _buildErrorText(),
            if (_mediaInfo != null) Expanded(child: _buildDownloadOptions()),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlInput() => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              controller: _urlController,
              textAlign: TextAlign.right,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'ألصق الرابط',
                border: InputBorder.none,
              ),
              onTap: () async {
                // Paste from clipboard when clicking the field
                if (_urlController.text.isEmpty) {
                  final clipboardData = await Clipboard.getData('text/plain');
                  if (clipboardData != null &&
                      clipboardData.text != null &&
                      clipboardData.text!.isNotEmpty) {
                    setState(() {
                      _urlController.text = clipboardData.text!;
                    });
                  }
                }
              },
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(left: 8),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isLoading ? null : _fetchMediaInfo,
            child: _isLoading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            )
                : Text('حمل'),
          ),
        ),
      ],
    ),
  );

  Widget _buildErrorText() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    child: Text(_errorMessage!,
        style: TextStyle(color: Colors.red, fontSize: 12),
        textAlign: TextAlign.right),
  );

  Widget _buildLoadingIndicator() => Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(child: CircularProgressIndicator()),
  );
}

class DownloadProgressDialog extends StatelessWidget {
  final String downloadId;

  const DownloadProgressDialog({required this.downloadId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('جاري التحميل', textDirection: TextDirection.rtl),
      content: Consumer<DownloadManager>(
        builder: (context, manager, _) {
          final download = manager.downloads[downloadId];
          if (download == null) return SizedBox();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: download.progress),
              SizedBox(height: 10),
              Text('${(download.progress * 100).toStringAsFixed(1)}%'),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          child: Text('إلغاء'),
          onPressed: () {
            Provider.of<DownloadManager>(context, listen: false)
                .cancelDownload(downloadId);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}