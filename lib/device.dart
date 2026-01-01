import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class DeviceIdService {
  static const _storage = FlutterSecureStorage();
  static const _hardwareIdKey = 'hardwareId';

  static Future<String> getHardwareId() async {
    // Try to get stored ID first
    String? storedId = await _storage.read(key: _hardwareIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      return storedId;
    }

    // Generate new ID
    String newId = await _generateHardwareId();

    // Store it permanently
    await _storage.write(key: _hardwareIdKey, value: newId);

    return newId;
  }

  static Future<String> _generateHardwareId() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use Android ID (unique per device + app)
        return 'android-${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor (unique per vendor + device)
        return 'ios-${iosInfo.identifierForVendor ?? const Uuid().v4()}';
      } else {
        // Web or desktop - use UUID
        return 'web-${const Uuid().v4()}';
      }
    } catch (e) {
      // Fallback if device info fails
      return 'uuid-${const Uuid().v4()}';
    }
  }

  // Optional: Reset hardware ID (for testing or logout)
  static Future<void> resetHardwareId() async {
    await _storage.delete(key: _hardwareIdKey);
  }
}