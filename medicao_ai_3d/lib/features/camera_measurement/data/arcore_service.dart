import 'package:flutter/services.dart';

class ArCoreAvailabilityInfo {
  const ArCoreAvailabilityInfo({
    required this.status,
    required this.isSupported,
    required this.isInstalled,
    required this.needsInstall,
    required this.depthSupported,
    this.error,
  });

  final String status;
  final bool isSupported;
  final bool isInstalled;
  final bool needsInstall;
  final bool depthSupported;
  final String? error;

  factory ArCoreAvailabilityInfo.fromMap(Map<String, dynamic> map) {
    return ArCoreAvailabilityInfo(
      status: map['status'] as String? ?? 'UNAVAILABLE',
      isSupported: map['isSupported'] as bool? ?? false,
      isInstalled: map['isInstalled'] as bool? ?? false,
      needsInstall: map['needsInstall'] as bool? ?? false,
      depthSupported: map['depthSupported'] as bool? ?? false,
      error: map['error'] as String?,
    );
  }

  static const ArCoreAvailabilityInfo unavailable = ArCoreAvailabilityInfo(
    status: 'UNSUPPORTED_DEVICE_OR_HOST',
    isSupported: false,
    isInstalled: false,
    needsInstall: false,
    depthSupported: false,
  );
}

class ArCoreService {
  static const MethodChannel _channel = MethodChannel(
    'br.com.medicaoai3d/arcore',
  );

  Future<ArCoreAvailabilityInfo> checkAvailability() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'checkAvailability',
      );
      if (raw == null) {
        return ArCoreAvailabilityInfo.unavailable;
      }
      return ArCoreAvailabilityInfo.fromMap(raw);
    } on MissingPluginException {
      return ArCoreAvailabilityInfo.unavailable;
    } on PlatformException catch (e) {
      return ArCoreAvailabilityInfo(
        status: 'ERROR',
        isSupported: false,
        isInstalled: false,
        needsInstall: false,
        depthSupported: false,
        error: e.message,
      );
    }
  }

  Future<bool> requestInstall() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'requestInstall',
      );
      return raw?['installed'] as bool? ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
