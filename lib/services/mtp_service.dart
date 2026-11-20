import 'package:flutter/services.dart';

class MtpDevice {
  final String id;
  final String name;
  final String state;

  const MtpDevice({
    required this.id,
    required this.name,
    this.state = 'device',
  });

  bool get isReady => state == 'device';
  String get displayName => name.isNotEmpty ? name : id;

  factory MtpDevice.fromMap(Map<dynamic, dynamic> map) {
    final id = (map['id'] ?? '').toString();
    final name = (map['name'] ?? id).toString();
    return MtpDevice(
      id: id,
      name: name,
      state: (map['state'] ?? 'device').toString(),
    );
  }
}

class MtpEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;

  const MtpEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
  });

  factory MtpEntry.fromMap(Map<dynamic, dynamic> map) {
    final name = (map['name'] ?? '').toString();
    final path = (map['path'] ?? name).toString();
    final isDir = map['isDirectory'] == true;
    final rawSize = map['size'];
    final size = rawSize is int
        ? rawSize
        : (rawSize is num ? rawSize.toInt() : int.tryParse('${rawSize ?? 0}') ?? 0);
    return MtpEntry(
      name: name,
      path: path,
      isDirectory: isDir,
      size: size,
    );
  }
}

class MtpService {
  static const MethodChannel _channel =
      MethodChannel('com.avarstudio.android_file_manager/mtp');

  Future<List<MtpDevice>> listDevices() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('listDevices');
    if (raw == null) return [];
    final devices = <MtpDevice>[];
    for (final item in raw) {
      if (item is Map) {
        final device = MtpDevice.fromMap(item);
        if (device.id.isNotEmpty) {
          devices.add(device);
        }
      }
    }
    return devices;
  }

  Future<List<MtpEntry>> listDirectory(String deviceId, String path) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'listDirectory',
      {'deviceId': deviceId, 'path': path},
    );
    if (raw == null) return [];
    final entries = <MtpEntry>[];
    for (final item in raw) {
      if (item is Map) {
        entries.add(MtpEntry.fromMap(item));
      }
    }
    return entries;
  }

  Future<void> pullFile({
    required String deviceId,
    required String remotePath,
    required String localDestinationPath,
  }) async {
    await _channel.invokeMethod<void>('pullFile', {
      'deviceId': deviceId,
      'remotePath': remotePath,
      'localDestinationPath': localDestinationPath,
    });
  }

  Future<void> pushFile({
    required String deviceId,
    required String localSourcePath,
    required String remoteDestinationPath,
  }) async {
    await _channel.invokeMethod<void>('pushFile', {
      'deviceId': deviceId,
      'localSourcePath': localSourcePath,
      'remoteDestinationPath': remoteDestinationPath,
    });
  }

  Future<void> pullDirectory({
    required String deviceId,
    required String remoteDirPath,
    required String localDestinationDirPath,
  }) async {
    await _channel.invokeMethod<void>('pullDirectory', {
      'deviceId': deviceId,
      'remoteDirPath': remoteDirPath,
      'localDestinationDirPath': localDestinationDirPath,
    });
  }

  Future<void> pushDirectory({
    required String deviceId,
    required String localSourceDirPath,
    required String remoteDestinationDirPath,
  }) async {
    await _channel.invokeMethod<void>('pushDirectory', {
      'deviceId': deviceId,
      'localSourceDirPath': localSourceDirPath,
      'remoteDestinationDirPath': remoteDestinationDirPath,
    });
  }

  Future<void> createDirectory(String deviceId, String parentPath, String folderName) async {
    final normalizedParent = parentPath.endsWith('/')
        ? parentPath.substring(0, parentPath.length - 1)
        : parentPath;
    final targetPath = normalizedParent.isEmpty ? '/$folderName' : '$normalizedParent/$folderName';
    await _channel.invokeMethod('createDirectory', {
      'deviceId': deviceId,
      'path': targetPath,
      'parentPath': parentPath,
      'folderName': folderName,
    });
  }

  Future<void> renameEntry(String deviceId, String oldPath, String newName) async {
    final parent = oldPath.contains('/') ? oldPath.substring(0, oldPath.lastIndexOf('/')) : '';
    final newPath = parent.isEmpty ? '/$newName' : '$parent/$newName';
    await _channel.invokeMethod('renameEntry', {
      'deviceId': deviceId,
      'oldPath': oldPath,
      'newPath': newPath,
      'newName': newName,
    });
  }

  Future<void> deleteEntry(String deviceId, String targetPath, {bool isDirectory = false}) async {
    await _channel.invokeMethod('deleteEntry', {
      'deviceId': deviceId,
      'path': targetPath,
      'isDirectory': isDirectory,
    });
  }
}
