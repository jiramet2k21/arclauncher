import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Hosts the "open app" animation. Four selectable styles share this host:
///
/// - `zoom`:   the icon grows while fading out (fast -> slow easing)
/// - `flip`:   a 3D page flip, then the icon grows and fades
/// - `pulse`:  the icon swells then collapses
/// - `circle`: a feathered black circle grows from the icon to fill the screen
///
/// The app is launched when the animation finishes.
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
  String _style = "zoom";
  bool _running = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
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
      final style = context.read<SettingsService>().openAppAnimationStyle;
      // Total time from animation start until the app launches (1/2/3 s from
      // settings). The animation is shorter and holds its final frame until it
      // elapses, so the activity transition never cuts it short.
      final launchDelay = Duration(seconds: context.read<SettingsService>().openAppLaunchDelay);
      Uint8List? bytes;
      double aspect = 1.0;
      try {
        final appsService = context.read<AppsService>();
        // Icons are small and already cached by AppsService, so the overlay can
        // start on the same frame as the key press (banners are much heavier
        // and used to delay the animation).
        bytes = await appsService.getAppIcon(app.packageName);
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
      if (bytes == null || bytes.isEmpty) {
        // Nothing to animate with: launch right away.
        await context.read<AppsService>().launchApp(app);
        return;
      }

      if (!mounted) return;
      setState(() {
        _app = app;
        _iconBytes = bytes;
        _iconAspect = aspect;
        _from = fromRect;
        _style = style;
      });

      _controller.reset();
      // Start the launch timer CONCURRENTLY with the animation so the app opens
      // when the configured delay has elapsed since the animation started — not
      // that long after it finished. The animation holds its final frame until
      // then, so the activity transition never cuts it short.
      final launchTimer = Future.delayed(launchDelay);
      await _controller.forward();
      await launchTimer;

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

  Widget _scrim(double t, {double alpha = 0.85, double fillUntil = 0.55}) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: alpha * (t / fillUntil).clamp(0.0, 1.0)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    final from = _from;
    if (app == null || from == null || _iconBytes == null) {
      return widget.child;
    }

    final screen = MediaQuery.of(context).size;
    final t = _controller.value;

    switch (_style) {
      case "flip":
        return _buildFlip(screen, from, t);
      case "pulse":
        return _buildPulse(screen, from, t);
      case "circle":
        return _buildCircle(screen, from, t);
      case "zoom":
      default:
        return _buildZoom(screen, from, t);
    }
  }

  Widget _buildZoom(Size screen, Rect from, double t) {
    final to = _targetRect(screen, from);
    final eased = Curves.easeOutCubic.transform(t);
    final rect = Rect.lerp(from, to, eased)!;
    // Fade towards 0.35 (not 0) so the icon stays faintly visible during the
    // hold that precedes the launch.
    final opacity = (1.0 - 0.65 * math.min(1.0, t / 0.65)).clamp(0.0, 1.0);

    return Stack(
      children: [
        widget.child,
        _scrim(t),
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                if (opacity > 0)
                  Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: Opacity(
                      opacity: opacity,
                      child: Image.memory(_iconBytes!, fit: BoxFit.contain),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlip(Size screen, Rect from, double t) {
    // First half: 3D page flip. Second half: grow towards the center and fade.
    final flipT = Interval(0.0, 0.5).transform(t);
    final growT = Interval(0.5, 1.0).transform(t);
    final to = _targetRect(screen, from);
    final eased = Curves.easeOutCubic.transform(growT);
    final rect = Rect.lerp(from, to, eased)!;
    final opacity = (1.0 - growT / 0.6).clamp(0.0, 1.0);
    final angle = math.pi * Curves.easeInOutCubic.transform(flipT);

    return Stack(
      children: [
        widget.child,
        _scrim(t, fillUntil: 0.5),
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 0, 0.0012)
                ..rotateY(angle),
              child: Opacity(
                opacity: opacity,
                child: Image.memory(_iconBytes!, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulse(Size screen, Rect from, double t) {
    // Swell to ~1.3x, then collapse while fading out.
    final growT = Interval(0.0, 0.45).transform(t);
    final fadeT = Interval(0.45, 1.0).transform(t);
    final scale = 1.0 + 0.3 * Curves.easeOut.transform(growT) * (1 - fadeT);
    final opacity = (1.0 - fadeT / 0.6).clamp(0.0, 1.0);

    return Stack(
      children: [
        widget.child,
        _scrim(t),
        Positioned.fromRect(
          rect: from,
          child: IgnorePointer(
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Image.memory(_iconBytes!, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircle(Size screen, Rect from, double t) {
    final center = from.center;
    final startRadius = from.width / 2;
    final maxRadius = math.max(
      math.max(center.dx, screen.width - center.dx),
      math.max(center.dy, screen.height - center.dy),
    );
    final eased = Curves.easeOutCubic.transform(t);
    final radius = startRadius + (maxRadius - startRadius) * eased;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _FeatherCirclePainter(center: center, radius: radius),
            ),
          ),
        ),
        // The icon fades quickly as the circle swallows it.
        Positioned.fromRect(
          rect: from,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1.0 - t / 0.35).clamp(0.0, 1.0),
              child: Image.memory(_iconBytes!, fit: BoxFit.contain),
            ),
          ),
        ),
      ],
    );
  }
}

/// Black circle with a feathered (gradient) edge, used by the "circle" style.
class _FeatherCirclePainter extends CustomPainter {
  final Offset center;
  final double radius;

  const _FeatherCirclePainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        <Color>[
          Colors.black,
          Colors.black.withValues(alpha: 0.9),
          Colors.transparent,
        ],
        <double>[0.0, 0.75, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_FeatherCirclePainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.radius != radius;
}
