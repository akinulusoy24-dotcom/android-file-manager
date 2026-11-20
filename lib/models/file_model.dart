enum FileSource { localMac, androidDevice }

class FileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int sizeBytes;
  final DateTime? modifiedAt;
  final FileSource source;

  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.sizeBytes = 0,
    this.modifiedAt,
    required this.source,
  });

  String get formattedSize {
    if (isDirectory) return '--';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
