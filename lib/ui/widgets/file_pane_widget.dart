import 'package:material_ui/material_ui.dart';

import '../../models/file_model.dart';

class FilePaneWidget extends StatelessWidget {
  final ValueChanged<FileEntry>? onToggleEntry;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onCreateFolder;
  final VoidCallback? onRenameSelected;
  final VoidCallback? onDeleteSelected;
  final String title;
  final IconData headerIcon;
  final String currentPath;
  final List<FileEntry> entries;
  final FileEntry? selectedEntry;
  final Set<String>? selectedPaths;
  final bool isLoading;
  final String? errorMessage;
  final String emptyMessage;
  final String transferButtonLabel;
  final IconData transferButtonIcon;
  final bool canTransfer;
  final VoidCallback onNavigateUp;
  final VoidCallback onRefresh;
  final ValueChanged<FileEntry> onSelectEntry;
  final ValueChanged<FileEntry> onOpenDirectory;
  final VoidCallback onTransferSelected;

  const FilePaneWidget({
    super.key,
    required this.title,
    required this.headerIcon,
    required this.currentPath,
    required this.entries,
    required this.selectedEntry,
    this.selectedPaths,
    required this.isLoading,
    required this.errorMessage,
    required this.emptyMessage,
    required this.transferButtonLabel,
    required this.transferButtonIcon,
    required this.canTransfer,
    required this.onNavigateUp,
    required this.onRefresh,
    this.onSelectAll,
    this.onClearSelection,
    this.onCreateFolder,
    this.onRenameSelected,
    this.onDeleteSelected,
    required this.onSelectEntry,
    this.onToggleEntry,
    required this.onOpenDirectory,
    required this.onTransferSelected,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Icon(headerIcon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: canTransfer ? onTransferSelected : null,
                  icon: Icon(transferButtonIcon, size: 16),
                  label: Text(
                    transferButtonLabel,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: currentPath == '/' ? null : onNavigateUp,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 17),
                  tooltip: 'Parent Folder',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: entries.isNotEmpty ? onSelectAll : null,
                  icon: const Icon(Icons.select_all_rounded, size: 16),
                  label: const Text('Select All'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: ((selectedPaths?.isNotEmpty ?? false) || selectedEntry != null)
                      ? onClearSelection
                      : null,
                  icon: const Icon(Icons.deselect_rounded, size: 16),
                  label: const Text('Clear'),
                ),
                IconButton(
                  onPressed: onCreateFolder,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                  tooltip: 'New Folder',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: onRenameSelected,
                  icon: const Icon(Icons.drive_file_rename_outline_rounded, size: 17),
                  tooltip: 'Rename',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: onDeleteSelected,
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                ),
                if ((selectedPaths?.length ?? 0) > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${selectedPaths!.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      currentPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Menlo',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text(
                    'Name',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(
                  width: 85,
                  child: Text(
                    'Size',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Modified',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(context, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme colorScheme) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 32, color: colorScheme.error),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: colorScheme.error),
              ),
            ],
          ),
        ),
      );
    }

    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        thickness: 0.5,
        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = (selectedPaths?.contains(entry.path) ?? false) || selectedEntry?.path == entry.path;

        return InkWell(
          onTap: () => onSelectEntry(entry),
          onDoubleTap: entry.isDirectory ? () => onOpenDirectory(entry) : null,
          child: Container(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.65)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                SizedBox(
                          width: 28,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => (onToggleEntry ?? onSelectEntry).call(entry),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                  entry.isDirectory
                      ? Icons.folder_rounded
                      : Icons.insert_drive_file_outlined,
                  size: 18,
                  color: entry.isDirectory
                      ? const Color(0xFF3B82F6)
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          entry.isDirectory ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                SizedBox(
                  width: 85,
                  child: Text(
                    entry.formattedSize,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: Text(
                    _formatDate(entry.modifiedAt),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
