import 'dart:typed_data';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum TvMediaPickerMode { image, video }

class TvMediaPicker extends StatefulWidget {
  final TvMediaPickerMode mode;

  const TvMediaPicker({super.key, required this.mode});

  static Future<TvMediaSelection?> show(
    BuildContext context, {
    required TvMediaPickerMode mode,
  }) async {
    final result = await showDialog<TvMediaSelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TvMediaPicker(mode: mode),
    );
    return result;
  }

  @override
  State<TvMediaPicker> createState() => _TvMediaPickerState();
}

class _TvMediaPickerState extends State<TvMediaPicker>
    with WidgetsBindingObserver {
  final FLauncherChannel _channel = FLauncherChannel();
  List<_MediaItem> _items = [];
  bool _loading = true;
  bool _permissionDenied = false;
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();

  /// Vertical stride of one grid row (tile height + spacing), computed from
  /// the actual grid geometry so D-pad scrolling lands on the right offset.
  double _rowStride = 220.0;

  /// Decode size (device pixels) for grid thumbnails.
  int _tileCacheWidth = 0;

  bool get isImage => widget.mode == TvMediaPickerMode.image;

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
      await _loadMedia();
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

    await _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });
    try {
      final data = isImage
          ? await _channel.getMediaStoreImages()
          : await _channel.getMediaStoreVideos();

      // NOTE: no File.exists() pre-check here — thousands of serial stat()
      // round-trips made the picker take seconds to open. Missing files show
      // as placeholder tiles via the thumbnail error path instead.
      final items = <_MediaItem>[];
      for (final entry in data) {
        final path = entry['path'] as String?;
        final uri = entry['uri'] as String?;
        if (path == null || uri == null) continue;
        items.add(
          _MediaItem(
            id: (entry['id'] as num).toInt(),
            name: entry['name'] as String? ?? 'Unknown',
            path: path,
            uri: uri,
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
    Navigator.of(context).pop(TvMediaSelection(uri: item.uri, path: item.path));
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
    final offset = index * _rowStride;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentScroll = _scrollController.offset;

    if (offset < currentScroll) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else if (offset + _rowStride > currentScroll + viewportHeight) {
      _scrollController.animateTo(
        offset + _rowStride - viewportHeight,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveFocus(1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveFocus(5);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-5);
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
    final title = isImage ? 'Select Image' : 'Select Video';
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
                  Icon(
                    isImage ? Icons.image : Icons.videocam,
                    color: accentColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  if (!_permissionDenied && !_loading)
                    Text(
                      '${_items.length} items',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
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
                  ? Center(
                      child: Text(
                        isImage
                            ? 'No images found on device'
                            : 'No videos found on device',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : _buildGrid(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _items.isEmpty
                      ? 'D-pad: navigate  •  Back: cancel'
                      : 'D-pad: navigate  •  Select: set wallpaper  •  Back: cancel',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
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
            'Grant permission to browse photos and videos',
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

  Widget _buildGrid() {
    const crossAxisCount = 5;
    const mainAxisSpacing = 12.0;
    const crossAxisSpacing = 12.0;
    const gridPadding = 24.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth -
                gridPadding * 2 -
                crossAxisSpacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final tileHeight = tileWidth / (16 / 9);
        _rowStride = tileHeight + mainAxisSpacing;
        _tileCacheWidth =
            (tileWidth * MediaQuery.devicePixelRatioOf(context)).round();

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(gridPadding),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 16 / 9,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            final isSelected = index == _selectedIndex;
            return _MediaTile(
              item: item,
              isSelected: isSelected,
              isImage: isImage,
              accentColor: Theme.of(context).colorScheme.primary,
              cacheWidth: _tileCacheWidth,
            );
          },
        );
      },
    );
  }
}

class _MediaItem {
  final int id;
  final String name;
  final String path;
  final String uri;

  _MediaItem({
    required this.id,
    required this.name,
    required this.path,
    required this.uri,
  });
}

class TvMediaSelection {
  final String uri;
  final String path;

  const TvMediaSelection({required this.uri, required this.path});
}

class _MediaTile extends StatelessWidget {
  final _MediaItem item;
  final bool isSelected;
  final bool isImage;
  final Color accentColor;
  final int cacheWidth;

  const _MediaTile({
    required this.item,
    required this.isSelected,
    required this.isImage,
    required this.accentColor,
    required this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? accentColor : Colors.white12,
          width: isSelected ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: isImage
                ? _ImageThumbnail(uri: item.uri, cacheWidth: cacheWidth)
                : _VideoThumbnail(
                    id: item.id,
                    path: item.path,
                    accentColor: accentColor,
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: isSelected
                ? accentColor.withValues(alpha: 0.2)
                : Colors.black45,
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageThumbnail extends StatefulWidget {
  final String uri;
  final int cacheWidth;

  const _ImageThumbnail({required this.uri, required this.cacheWidth});

  @override
  State<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends State<_ImageThumbnail> {
  late final Future<Uint8List?> _thumb =
      FLauncherChannel().getMediaStoreImageThumbnail(widget.uri);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumb,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const ColoredBox(
            color: Colors.black26,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: widget.cacheWidth,
          filterQuality: FilterQuality.low,
        );
      },
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final int id;
  final String path;
  final Color accentColor;

  const _VideoThumbnail({
    required this.id,
    required this.path,
    required this.accentColor,
  });

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late final Future<Uint8List?> _thumb = FLauncherChannel()
      .getMediaStoreVideoThumbnail(widget.id, path: widget.path);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumb,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            else
              const ColoredBox(color: Colors.black26),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
          ],
        );
      },
    );
  }
}
