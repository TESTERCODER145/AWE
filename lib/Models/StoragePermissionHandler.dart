import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';

class StoragePermissionHandler {
  static Future<bool> requestStoragePermission() async {
    // Get Android version
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    // For Android 11 (API level 30) and above
    if (androidInfo.version.sdkInt >= 30) {
      // Request MANAGE_EXTERNAL_STORAGE permission
      if (!await Permission.manageExternalStorage.isGranted) {
        // Open system settings for MANAGE_EXTERNAL_STORAGE
        final intent = AndroidIntent(
          action: 'android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION',
        );
        await intent.launch();

        // Check if permission was granted
        return await Permission.manageExternalStorage.isGranted;
      }
      return true;
    }
    // For Android 10 and below
    else {
      PermissionStatus status = await Permission.storage.status;
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
  }
}