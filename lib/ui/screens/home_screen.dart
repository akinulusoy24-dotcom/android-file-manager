import 'package:flutter/services.dart';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/file_model.dart';
import '../../services/mtp_service.dart';
import '../../services/local_file_service.dart';
import '../widgets/file_pane_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _selectedLocalPaths = {};
  final Set<String> _selectedRemotePaths = {};
  int? _lastLocalAnchorIndex;
  int? _lastRemoteAnchorIndex;

  void _selectAll({required bool isLocal}) {
    final entries = isLocal ? _localEntries : _remoteEntries;
    setState(() {
      if (isLocal) {
        _selectedLocalPaths
          ..clear()
          ..addAll(entries.map((e) => e.path));
        _selectedLocalEntry = entries.isNotEmpty ? entries.last : null;
        _lastLocalAnchorIndex = entries.isNotEmpty ? entries.length - 1 : null;
      } else {
        _selectedRemotePaths
          ..clear()
          ..addAll(entries.map((e) => e.path));
        _selectedRemoteEntry = entries.isNotEmpty ? entries.last : null;
        _lastRemoteAnchorIndex = entries.isNotEmpty ? entries.length - 1 : null;
      }
    });
  }

  void _clearSelection({required bool isLocal}) {
    setState(() {
      if (isLocal) {
        _selectedLocalPaths.clear();
        _selectedLocalEntry = null;
        _lastLocalAnchorIndex = null;
      } else {
        _selectedRemotePaths.clear();
        _selectedRemoteEntry = null;
        _lastRemoteAnchorIndex = null;
      }
    });
  }

  void _handleMultiSelect({
    required bool isLocal,
    required FileEntry entry,
    bool forceToggle = false,
  }) {
    final entries = isLocal ? _localEntries : _remoteEntries;
    final selectedSet = isLocal ? _selectedLocalPaths : _selectedRemotePaths;
    final currentIndex = entries.indexWhere((e) => e.path == entry.path);
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final shiftDown = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    final metaOrCtrlDown = keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight) ||
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);

    final lastIndex = isLocal ? _lastLocalAnchorIndex : _lastRemoteAnchorIndex;

    setState(() {
      if (shiftDown && lastIndex != null && lastIndex >= 0 && currentIndex >= 0) {
        final start = lastIndex < currentIndex ? lastIndex : currentIndex;
        final end = lastIndex > currentIndex ? lastIndex : currentIndex;
        for (var i = start; i <= end; i++) {
          selectedSet.add(entries[i].path);
        }
      } else if (metaOrCtrlDown || forceToggle) {
        if (selectedSet.contains(entry.path)) {
          selectedSet.remove(entry.path);
        } else {
          selectedSet.add(entry.path);
        }
        if (currentIndex >= 0) {
          if (isLocal) {
            _lastLocalAnchorIndex = currentIndex;
          } else {
            _lastRemoteAnchorIndex = currentIndex;
          }
        }
      } else {
        if (selectedSet.contains(entry.path) && selectedSet.length == 1) {
          selectedSet.clear();
        } else {
          if (selectedSet.contains(entry.path)) {
            selectedSet.remove(entry.path);
          } else {
            selectedSet.add(entry.path);
          }
        }
        if (currentIndex >= 0) {
          if (isLocal) {
            _lastLocalAnchorIndex = currentIndex;
          } else {
            _lastRemoteAnchorIndex = currentIndex;
          }
        }
      }

      if (isLocal) {
        _selectedLocalEntry = selectedSet.isEmpty ? null : entry;
      } else {
        _selectedRemoteEntry = selectedSet.isEmpty ? null : entry;
      }
    });
  }
  final MtpService _mtpService = MtpService();
  final LocalFileService _localService = LocalFileService();

  late String _localPath;
  List<FileEntry> _localEntries = [];
  FileEntry? _selectedLocalEntry;
  bool _isLoadingLocal = false;
  String? _localError;

  List<MtpDevice> _devices = [];
  MtpDevice? _selectedDevice;
  String _remotePath = '/sdcard';
  List<FileEntry> _remoteEntries = [];
  FileEntry? _selectedRemoteEntry;
  bool _isLoadingRemote = false;
  String? _remoteError;

  bool _isTransferring = false;
  @override
  void initState() {
    super.initState();
    _localPath = _localService.defaultStartDirectory;
    _loadLocalDirectory(_localPath);
    _refreshDevices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showConnectionGuideDialog();
      }
    });
  }

  Future<void> _pickLocalDirectory() async {
    if (_isTransferring) return;
    try {
      final selectedDirectory = await getDirectoryPath(
        initialDirectory: _localPath,
        confirmButtonText: 'Select Folder',
      );
      if (!mounted || selectedDirectory == null || selectedDirectory.isEmpty) {
        return;
      }
      await _loadLocalDirectory(selectedDirectory);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localError = 'Failed to select folder: $e';
      });
    }
  }

  Future<void> _showConnectionGuideDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final steps = [
          (
            '1',
            'Connect via USB',
            'Plug your Android device into your Mac using a USB cable and unlock the screen.',
          ),
          (
            '2',
            'Select File Transfer (MTP)',
            'Open the USB notification on your phone and choose File Transfer (MTP) mode.',
          ),
          (
            '3',
            'Authorize Connection',
            'Tap Allow if your phone prompts you to allow access to device data.',
          ),
          (
            '4',
            'Scan & Transfer Files',
            'Click the refresh button at the top right, select your device, and transfer files between Mac and your device.',
          ),
        ];

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.phonelink_setup_rounded, color: colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Phone Connection Guide',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Follow these steps to connect your Android device to your Mac:',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                ...steps.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          child: Text(
                            item.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.$3,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _refreshDevices();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Scan Devices'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got It'),
            ),
          ],
        );
      },
    );
  }

  String _parentPath(String current) {
    if (current == '/' || current.isEmpty) return '/';
    final normalized =
        current.endsWith('/') ? current.substring(0, current.length - 1) : current;
    final lastSlash = normalized.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return normalized.substring(0, lastSlash);
  }

  Future<void> _loadLocalDirectory(String path) async {
    setState(() {
      _isLoadingLocal = true;
      _localError = null;
      _selectedLocalEntry = null;
    });

    try {
      final entries = await _localService.listDirectory(path);
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _localEntries = entries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocal = false;
        });
      }
    }
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _isLoadingRemote = true;
      _remoteError = null;
    });

    try {
      final devices = await _mtpService.listDevices();
      if (!mounted) return;

      MtpDevice? nextSelected;
      if (_selectedDevice != null) {
        for (final d in devices) {
          if (d.id == _selectedDevice!.id) {
            nextSelected = d;
            break;
          }
        }
      }
      nextSelected ??= devices.isNotEmpty ? devices.first : null;

      setState(() {
        _devices = devices;
        _selectedDevice = nextSelected;
      });

      if (nextSelected != null && nextSelected.isReady) {
        await _loadRemoteDirectory(_remotePath);
      } else if (nextSelected != null && !nextSelected.isReady) {
        setState(() {
          _remoteEntries = [];
          _remoteError =
              'Device "${nextSelected!.id}" is "${nextSelected.state}". Please check File Transfer (MTP) authorization on your phone.';
          _isLoadingRemote = false;
        });
      } else {
        setState(() {
          _remoteEntries = [];
          _remoteError =
              'No Android device detected. Connect a device via USB and enable File Transfer (MTP).';
          _isLoadingRemote = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _devices = [];
        _selectedDevice = null;
        _remoteEntries = [];
        _remoteError = e.toString();
        _isLoadingRemote = false;
      });
    }
  }

  Future<void> _loadRemoteDirectory(String path) async {
    final device = _selectedDevice;
    if (device == null || !device.isReady) return;

    setState(() {
      _isLoadingRemote = true;
      _remoteError = null;
      _selectedRemoteEntry = null;
    });

    try {
      final entries = await _mtpService.listDirectory(device.id, path).then((items) => items.map((e) => FileEntry(name: e.name, path: e.path, isDirectory: e.isDirectory, sizeBytes: e.isDirectory ? 0 : e.size, source: FileSource.localMac,)).toList());
      if (!mounted) return;
      setState(() {
        _remotePath = path;
        _remoteEntries = entries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _remoteError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRemote = false;
        });
      }
    }
  }

  
  Future<String?> _promptTextDialog({
    required String title,
    required String labelText,
    String initialValue = '',
    String confirmLabel = 'OK',
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: labelText),
          onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteDialog(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          count == 1
              ? 'Are you sure you want to delete the selected item?'
              : 'Are you sure you want to delete $count selected items?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _createFolder({required bool isLocal}) async {
    final folderName = await _promptTextDialog(
      title: 'New Folder',
      labelText: 'Folder name',
      confirmLabel: 'Create',
    );
    if (folderName == null || folderName.isEmpty) return;

    try {
      if (isLocal) {
        final target = Directory('$_localPath/$folderName');
        await target.create(recursive: true);
        await _loadLocalDirectory(_localPath);
      } else {
        final device = _selectedDevice;
        if (device == null) return;
        await _mtpService.createDirectory(device.id, _remotePath, folderName);
        await _loadRemoteDirectory(_remotePath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create folder failed: $e')),
      );
    }
  }

  Future<void> _renameSelected({required bool isLocal}) async {
    final entries = isLocal ? _localEntries : _remoteEntries;
    final selectedSet = isLocal ? _selectedLocalPaths : _selectedRemotePaths;
    final singleSelected = isLocal ? _selectedLocalEntry : _selectedRemoteEntry;

    FileEntry? target;
    if (selectedSet.length == 1) {
      final path = selectedSet.first;
      for (final item in entries) {
        if (item.path == path) {
          target = item;
          break;
        }
      }
    } else if (selectedSet.isEmpty && singleSelected != null) {
      target = singleSelected;
    }
    if (target == null) return;

    final newName = await _promptTextDialog(
      title: 'Rename',
      labelText: 'New name',
      initialValue: target.name,
      confirmLabel: 'Rename',
    );
    if (newName == null || newName.isEmpty || newName == target.name) return;

    try {
      if (isLocal) {
        final parent = File(target.path).parent.path;
        final newPath = '$parent/$newName';
        if (target.isDirectory) {
          await Directory(target.path).rename(newPath);
        } else {
          await File(target.path).rename(newPath);
        }
        await _loadLocalDirectory(_localPath);
      } else {
        final device = _selectedDevice;
        if (device == null) return;
        await _mtpService.renameEntry(device.id, target.path, newName);
        await _loadRemoteDirectory(_remotePath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rename failed: $e')),
      );
    }
  }

  Future<void> _deleteSelected({required bool isLocal}) async {
    final entries = isLocal ? _localEntries : _remoteEntries;
    final selectedSet = isLocal ? _selectedLocalPaths : _selectedRemotePaths;
    final singleSelected = isLocal ? _selectedLocalEntry : _selectedRemoteEntry;

    final targets = <FileEntry>[];
    if (selectedSet.isNotEmpty) {
      for (final item in entries) {
        if (selectedSet.contains(item.path)) {
          targets.add(item);
        }
      }
    } else if (singleSelected != null) {
      targets.add(singleSelected);
    }
    if (targets.isEmpty) return;

    final confirmed = await _confirmDeleteDialog(targets.length);
    if (!confirmed) return;

    try {
      if (isLocal) {
        for (final item in targets) {
          if (item.isDirectory) {
            await Directory(item.path).delete(recursive: true);
          } else {
            await File(item.path).delete();
          }
        }
        _clearSelection(isLocal: true);
        await _loadLocalDirectory(_localPath);
      } else {
        final device = _selectedDevice;
        if (device == null) return;
        for (final item in targets) {
          await _mtpService.deleteEntry(device.id, item.path, isDirectory: item.isDirectory);
        }
        _clearSelection(isLocal: false);
        await _loadRemoteDirectory(_remotePath);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _pushSelectedToAndroid() async {
    final device = _selectedDevice;
    if (device == null || !device.isReady || _isTransferring) return;

    final targets = <FileEntry>[];
    if (_selectedLocalPaths.isNotEmpty) {
      for (final e in _localEntries) {
        if (_selectedLocalPaths.contains(e.path)) {
          targets.add(e);
        }
      }
    } else if (_selectedLocalEntry != null) {
      targets.add(_selectedLocalEntry!);
    }
    if (targets.isEmpty) return;

    setState(() {
      _isTransferring = true;
    });

    try {
      final total = targets.length;
      for (var i = 0; i < total; i++) {
        final selected = targets[i];
        setState(() {});

        final remoteDest = (_remotePath == '/' || _remotePath.isEmpty)
            ? '/${selected.name}'
            : '$_remotePath/${selected.name}';

        if (selected.isDirectory) {
          await _mtpService.pushDirectory(
            deviceId: device.id,
            localSourceDirPath: selected.path,
            remoteDestinationDirPath: _remotePath,
          );
        } else {
          await _mtpService.pushFile(
            deviceId: device.id,
            localSourcePath: selected.path,
            remoteDestinationPath: remoteDest,
          );
        }
      }
      await _loadRemoteDirectory(_remotePath);
    } catch (e) { // Transfer error handled } finally {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
      }
    }
  }

  Future<void> _pullSelectedToMac() async {
    final device = _selectedDevice;
    if (device == null || !device.isReady || _isTransferring) return;

    final targets = <FileEntry>[];
    if (_selectedRemotePaths.isNotEmpty) {
      for (final e in _remoteEntries) {
        if (_selectedRemotePaths.contains(e.path)) {
          targets.add(e);
        }
      }
    } else if (_selectedRemoteEntry != null) {
      targets.add(_selectedRemoteEntry!);
    }
    if (targets.isEmpty) return;

    setState(() {
      _isTransferring = true;
    });

    try {
      final total = targets.length;
      for (var i = 0; i < total; i++) {
        final selected = targets[i];
        setState(() {});

        final localDest = (_localPath.endsWith(Platform.pathSeparator))
            ? '$_localPath${selected.name}'
            : '$_localPath${Platform.pathSeparator}${selected.name}';

        if (selected.isDirectory) {
          await _mtpService.pullDirectory(
            deviceId: device.id,
            remoteDirPath: selected.path,
            localDestinationDirPath: localDest,
          );
        } else {
          await _mtpService.pullFile(
            deviceId: device.id,
            remotePath: selected.path,
            localDestinationPath: localDest,
          );
        }
      }
      await _loadLocalDirectory(_localPath);
    } catch (e) { // Transfer error handled } finally {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canUseDevice =
        !_isTransferring && _selectedDevice != null && _selectedDevice!.isReady;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Android File Manager',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colorScheme.outlineVariant),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isTransferring ? null : _pickLocalDirectory,
            icon: const Icon(Icons.folder_open_rounded, size: 16),
            label: const Text(
              'Select Folder',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _showConnectionGuideDialog,
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            tooltip: 'Phone Connection Guide',
          ),
          const SizedBox(width: 4),
          Row(
            children: [
              const Icon(Icons.smartphone_rounded, size: 17),
              const SizedBox(width: 6),
              const Text(
                'Device:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedDevice?.id,
                hint: const Text(
                  'No Device',
                  style: TextStyle(fontSize: 12.5),
                ),
                underline: const SizedBox.shrink(),
                items: _devices.map((device) {
                  return DropdownMenuItem<String>(
                    value: device.id,
                    child: Text(
                      device.displayName,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  );
                }).toList(),
                onChanged: _isTransferring
                    ? null
                    : (deviceId) {
                        if (deviceId == null) return;
                        final match = _devices.firstWhere((d) => d.id == deviceId);
                        setState(() {
                          _selectedDevice = match;
                          _remotePath = '/sdcard';
                        });
                        if (match.isReady) {
                          _loadRemoteDirectory('/sdcard');
                        } else {
                          setState(() {
                            _remoteEntries = [];
                            _remoteError =
                                'Device "${match.id}" is "${match.state}".';
                          });
                        }
                      },
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _isTransferring ? null : _refreshDevices,
                icon: const Icon(Icons.devices_other_rounded, size: 18),
                tooltip: 'Refresh Connected Devices',
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: FilePaneWidget(
                      title: 'Mac (Local)',
                      headerIcon: Icons.laptop_mac_rounded,
                      currentPath: _localPath,
                      entries: _localEntries,
                      selectedEntry: _selectedLocalEntry,
                      selectedPaths: _selectedLocalPaths,
                      isLoading: _isLoadingLocal,
                      errorMessage: _localError,
                      emptyMessage: 'This folder is empty.',
                      transferButtonLabel: 'Push to Android',
                      transferButtonIcon: Icons.arrow_forward_rounded,
                      canTransfer: canUseDevice && (_selectedLocalEntry != null || _selectedLocalPaths.isNotEmpty),
                      onNavigateUp: () =>
                          _loadLocalDirectory(_parentPath(_localPath)),
                      onRefresh: () => _loadLocalDirectory(_localPath),
                      onSelectEntry: (entry) => _handleMultiSelect(isLocal: true, entry: entry),
                      onToggleEntry: (entry) => _handleMultiSelect(isLocal: true, entry: entry, forceToggle: true),
                      onOpenDirectory: (entry) =>
                          _loadLocalDirectory(entry.path),
                      onTransferSelected: _pushSelectedToAndroid,
                      onSelectAll: () => _selectAll(isLocal: true),
                      onClearSelection: () => _clearSelection(isLocal: true),
                      onCreateFolder: () => _createFolder(isLocal: true),
                      onRenameSelected: () => _renameSelected(isLocal: true),
                      onDeleteSelected: () => _deleteSelected(isLocal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilePaneWidget(
                      title: 'Android Device',
                      headerIcon: Icons.android_rounded,
                      currentPath: _remotePath,
                      entries: _remoteEntries,
                      selectedEntry: _selectedRemoteEntry,
                      selectedPaths: _selectedRemotePaths,
                      isLoading: _isLoadingRemote,
                      errorMessage: _remoteError,
                      emptyMessage: 'Folder is empty or inaccessible.',
                      transferButtonLabel: 'Pull to Mac',
                      transferButtonIcon: Icons.arrow_back_rounded,
                      canTransfer: canUseDevice && (_selectedRemoteEntry != null || _selectedRemotePaths.isNotEmpty),
                      onNavigateUp: () =>
                          _loadRemoteDirectory(_parentPath(_remotePath)),
                      onRefresh: () => _loadRemoteDirectory(_remotePath),
                      onSelectEntry: (entry) => _handleMultiSelect(isLocal: false, entry: entry),
                      onToggleEntry: (entry) => _handleMultiSelect(isLocal: false, entry: entry, forceToggle: true),
                      onOpenDirectory: (entry) =>
                          _loadRemoteDirectory(entry.path),
                      onTransferSelected: _pullSelectedToMac,
                      onSelectAll: () => _selectAll(isLocal: false),
                      onClearSelection: () => _clearSelection(isLocal: false),
                      onCreateFolder: () => _createFolder(isLocal: false),
                      onRenameSelected: () => _renameSelected(isLocal: false),
                      onDeleteSelected: () => _deleteSelected(isLocal: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
