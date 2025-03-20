import 'dart:io';
import 'package:downloadsplatform/screens/BottomBar/DownloadProgressScreen.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';

class HistoryDownload extends StatefulWidget {
  @override
  _HistoryDownloadScreenState createState() => _HistoryDownloadScreenState();
}

class _HistoryDownloadScreenState extends State<HistoryDownload> {
  late Database _database;
  List<Map<String, dynamic>> _completedDownloads = [];
  late DownloadManager _downloadManager;

  @override
  void initState() {
    super.initState();
    _initDatabase();
    final BuildContext context = this.context;
    _downloadManager = Provider.of<DownloadManager>(context, listen: false);
    _downloadManager.addListener(_update);
  }

  void _update() {
    // Reload database entries when updates occur
    _loadDownloads().then((_) => setState(() {}));
  }

  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'downloads.db');

    // Check if database exists
    final exists = await databaseExists(path);

    if (!exists) {
      // Create new database
      await openDatabase(path, version: 2,
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
    }

    _database = await openDatabase(
      path,
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
    );
    await _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    try {
      final downloads = await _database.query('downloads');
      setState(() => _completedDownloads = downloads);
    } catch (e) {
      print('Error loading downloads: $e');
      // Handle table creation if missing
      await _database.execute('''
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
  }

  Future<void> _deleteDownload(int id, String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      await _database.delete(
        'downloads',
        where: 'id = ?',
        whereArgs: [id],
      );

      await _loadDownloads();
    } catch (e) {
      print('Error deleting download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDownloads = Provider.of<DownloadManager>(context).downloads.values.toList();
    final allDownloads = [...activeDownloads, ..._completedDownloads];

    return Scaffold(
      appBar: AppBar(
        title: Text('التحميلات', textDirection: TextDirection.rtl),
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        itemCount: allDownloads.length,
        itemBuilder: (context, index) {
          final item = allDownloads[index];
          return item is DownloadInfo
              ? _buildActiveDownload(item)
              : _buildCompletedDownload(item as Map<String, dynamic>);
        },
      ),
    );
  }

  Widget _buildDownloadItem(dynamic item) {
    if (item is DownloadInfo) {
      return _buildActiveDownload(item);
    }
    return _buildCompletedDownload(item as Map<String, dynamic>);
  }

  Widget _buildActiveDownload(DownloadInfo download) {
    // Add status-based visibility
    if (download.status == DownloadStatus.completed) {
      return SizedBox.shrink(); // Hide completed downloads from active list
    }
    return Card(
      margin: EdgeInsets.all(8),
      child: ListTile(
        title: Text(download.fileName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (download.status == DownloadStatus.downloading) ...[
              LinearProgressIndicator(value: download.progress),
              SizedBox(height: 4),
              Text('${(download.progress * 100).toStringAsFixed(1)}%'),
              Text('جاري التحميل...', style: TextStyle(color: Colors.grey)),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.cancel),
          onPressed: () => _downloadManager.cancelDownload(
              '${download.url}_${download.formatId}'
          ),
        ),
      ),
    );
  }
  Widget _buildCompletedDownload(Map<String, dynamic> download) {
    return Dismissible(
      key: Key(download['id'].toString()),
      direction: DismissDirection.endToStart, // Right-to-left swipe in RTL
      background: Container(
        color: Colors.red,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Directionality( // Force LTR layout for the row
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: const [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 8),
                Text('حذف',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold
                    )),
              ],
            ),
          ),
        ),
      ),
      onDismissed: (_) => _deleteDownload(download['id'], download['filePath']),
      child: Card(
        margin: const EdgeInsets.all(8),
        child: ListTile(
          title: Text(
            download['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16),
          ),
          subtitle: Text(
            DateTime.parse(download['downloadDate'])
                .toLocal()
                .toString()
                .split('.')[0],
          ),
          trailing: Builder(
            builder: (BuildContext currentContext) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _redownloadFile(currentContext, download);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _redownloadFile(BuildContext currentContext, Map<String, dynamic> download) async {
    final manager = Provider.of<DownloadManager>(currentContext, listen: false);

    try {
      // Delete existing file
      final file = File(download['filePath']);
      if (await file.exists()) await file.delete();

      // Delete database entry
      await _database.delete(
        'downloads',
        where: 'id = ?',
        whereArgs: [download['id']],
      );

      // Get original filename from path
      final fileName = download['filePath'].split('/').last;

      // Start new download
      manager.startDownload(
        url: download['url'],
        formatId: download['format_id'],
        fileName: fileName,
      );

      // Refresh the list
      await _loadDownloads();
    } catch (e) {
      print('Redownload error: $e');
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text('فشل إعادة التحميل ')),
      );
    }
  }
  @override
  void dispose() {
    _downloadManager.removeListener(_update);
    super.dispose();
  }
}