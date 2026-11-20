import 'dart:io';

import '../models/file_model.dart';

class LocalFileService {
  String get defaultStartDirectory {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      final downloads = '$home/Downloads';
      if (Directory(downloads).existsSync()) {
        return downloads;
      }
      return home;
    }
    return '/';
  }

  Future<List<FileEntry>> listDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw Exception('Local directory does not exist: $directoryPath');
    }

    final entities = await dir.list(followLinks: false).toList();
    final entries = <FileEntry>[];

    for (final entity in entities) {
      final segments = entity.path.split(Platform.pathSeparator);
      final name = segments.isNotEmpty ? segments.last : entity.path;
      if (name.isEmpty) continue;

      try {
        final stat = await entity.stat();
        final isDir = stat.type == FileSystemEntityType.directory;
        entries.add(
          FileEntry(
            name: name,
            path: entity.path,
            isDirectory: isDir,
            sizeBytes: isDir ? 0 : stat.size,
            modifiedAt: stat.modified,
            source: FileSource.localMac,
          ),
        );
      } catch (_) {
        // Skip entries with restricted permissions on macOS.
      }
    }

    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }
}
