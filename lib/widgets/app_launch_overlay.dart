import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Hosts the "open app" animation: the app icon of the pressed card expands
/// from the card's position to the center of the screen while a scrim fades
/// in, right before the app is launched.
class AppLaunchOverlayHost extends StatefulWidget {
  final Widget child;

  const AppLaunchOverlayHost({super.key, required this.child});

  static _AppLaunchOverlayHostState? of(BuildContext context) =>
      context.findAncestorStateOfType<_AppLaunchOverlayHostState>();

  @override
  State<AppLaunchOverlayHost> createState() => _AppLaunchOverlayHostState();
}

class _AppLaunchOverlayHostState extends State<AppLaunchOverlayHost> with SingleTickerProviderStateMixin {
  App? _app;
  Uint8List? _iconBytes;
  double _iconAspect = 1.0;
  Rect? _from;
  bool _running = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Runs the animation and then launches [app]. Safe to call concurrently:
  /// overlapping requests are ignored while an animation is running.
  Future<void> start(App app, Rect fromRect) async {
    if (_running) return;
    _running = true;
    try {
      Uint8List? bytes;
      double aspect = 1.0;
      try {
        final appsService = context.read<AppsService>();
        bytes = await appsService.getAppBanner(app.packageName);
        if (bytes.isEmpty) {
          bytes = await appsService.getAppIcon(app.packageName);
        }
        if (bytes.isNotEmpty) {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          aspect = frame.image.width / math.max(1, frame.image.height);
          frame.image.dispose();
          codec.dispose();
        }
      } catch (_) {
        bytes = null;
      }

      if (!mounted) return;
      setState(() {
        _app = app;
        _iconBytes = (bytes != null && bytes.isNotEmpty) ? bytes : null;
        _iconAspect = aspect;
        _from = fromRect;
      });

      _controller.reset();
      await _controller.forward();

      await context.read<AppsService>().launchApp(app);

      if (!mounted) return;
      _controller.reset();
      setState(() {
        _app = null;
        _iconBytes = null;
        _from = null;
      });
    } finally {
      _running = false;
    }
  }

  Rect _targetRect(Size screen, Rect from) {
    final width = math.min(screen.width * 0.72, from.width * 2.6);
    final height = width / math.max(0.1, _iconAspect);
    return Rect.fromCenter(center: screen.center(Offset.zero), width: width, height: height);
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    final from = _from;
    if (app == null || from == null) {
      return widget.child;
    }

    final screen = MediaQuery.of(context).size;
    final to = _targetRect(screen, from);
    final eased = Curves.easeOutCubic.transform(_controller.value);
    final rect = Rect.lerp(from, to, eased)!;
    final scrim = (_controller.value / 0.55).clamp(0.0, 1.0);

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.85 * scrim),
              child: Stack(
                children: [
                  if (_iconBytes != null)
                    Positioned(
                      left: rect.left,
                      top: rect.top,
                      width: rect.width,
                      height: rect.height,
                      child: Image.memory(_iconBytes!, fit: BoxFit.contain),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
