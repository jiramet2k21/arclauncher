import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvFolderPicker extends StatefulWidget {
  const TvFolderPicker({super.key});

  static Future<TvFolderSelection?> show(BuildContext context) async {
    return showDialog<TvFolderSelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TvFolderPicker(),
    );
  }

  @override
  State<TvFolderPicker> createState() => _TvFolderPickerState();
}

class _TvFolderPickerState extends State<TvFolderPicker>
    with WidgetsBindingObserver {
  final FLauncherChannel _channel = FLauncherChannel();
  List<_FolderItem> _items = [];
  bool _loading = true;
  bool _permissionDenied = false;
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      _checkPermissionAndLoad();
    }
  }

  Future<void> _checkPermissionAndLoad() async {
    final granted = await _channel.checkMediaPermissions();
    if (granted && mounted) {
      await _loadFolders();
    }
  }

  Future<void> _requestPermissionAndLoad() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });

    bool granted = await _channel.checkMediaPermissions();

    if (!granted) {
      await _channel.requestMediaPermissions();
      await Future.delayed(const Duration(milliseconds: 500));
      granted = await _channel.checkMediaPermissions();
    }

    if (!granted) {
      if (mounted) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
      }
      return;
    }

    await _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });
    try {
      final data = await _channel.getMediaStoreImageFolders();
      final items = <_FolderItem>[];
      for (final entry in data) {
        final id = entry['id'] as String?;
        if (id == null) continue;
        items.add(
          _FolderItem(
            id: id,
            name: entry['name'] as String? ?? 'Unknown',
            count: (entry['count'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          if (items.isNotEmpty) _selectedIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _select() {
    if (_items.isEmpty) return;
    final item = _items[_selectedIndex];
    Navigator.of(context).pop(
      TvFolderSelection(id: item.id, name: item.name, count: item.count),
    );
  }

  void _moveFocus(int direction) {
    if (_items.isEmpty) return;
    int newIndex = _selectedIndex + direction;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= _items.length) newIndex = _items.length - 1;
    if (newIndex != _selectedIndex) {
      setState(() => _selectedIndex = newIndex);
      _ensureVisible(newIndex);
    }
  }

  void _ensureVisible(int index) {
    const itemExtent = 72.0;
    final offset = index * itemExtent;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentScroll = _scrollController.offset;

    if (offset < currentScroll) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else if (offset + itemExtent > currentScroll + viewportHeight) {
      _scrollController.animateTo(
        offset + itemExtent - viewportHeight,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      _select();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      insetPadding: const EdgeInsets.all(40),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
              child: Row(
                children: [
                  Icon(Icons.folder, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Select folder',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  if (!_permissionDenied && !_loading)
                    Text(
                      '${_items.length} folders',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white54),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _permissionDenied
                      ? _buildPermissionDenied(accentColor)
                      : _items.isEmpty
                          ? const Center(
                              child: Text(
                                'No image folders found on device',
                                style: TextStyle(color: Colors.white54, fontSize: 16),
                              ),
                            )
                          : _buildList(),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'D-pad: navigate  •  Select: use folder  •  Back: cancel',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied(Color accentColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, color: Colors.white38, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Media access permission is required',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Grant permission to browse image folders',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _requestPermissionAndLoad,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: const Icon(Icons.settings),
            label: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isSelected = index == _selectedIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white12,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white54,
                  size: 26,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${item.count} images',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FolderItem {
  final String id;
  final String name;
  final int count;

  _FolderItem({required this.id, required this.name, required this.count});
}

class TvFolderSelection {
  final String id;
  final String name;
  final int count;

  const TvFolderSelection({
    required this.id,
    required this.name,
    required this.count,
  });
}
