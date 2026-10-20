/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Replaces a live [BackdropFilter] over the (static) wallpaper with a
/// pre-blurred snapshot of the wallpaper that is blitted behind [child].
///
/// A live [BackdropFilter] re-samples and re-blurs the scene on *every*
/// composited frame, which is expensive on low-end GPUs (e.g. Android TV
/// sticks). Because the wallpaper is static, we blur it once into a [ui.Image]
/// and simply copy the region located under this widget each frame — a cheap
/// blit that naturally follows scrolling through the paint offset.
///
/// Falls back to a live [BackdropFilter] while the snapshot is being prepared
/// or when the wallpaper is a video (which is not static).
///
/// Full-screen blurred wallpaper layer (no foreground content).
class CachedBlurLayer extends StatefulWidget {
  final double sigma;

  const CachedBlurLayer({super.key, required this.sigma});

  @override
  State<CachedBlurLayer> createState() => _CachedBlurLayerState();
}

class _CachedBlurLayerState extends _CachedBlurBackgroundState<CachedBlurLayer> {
  @override
  double get sigma => widget.sigma;

  @override
  Widget buildBlurContent(Widget blurBackground) => blurBackground;

  @override
  Widget buildLiveBlur() => BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: const SizedBox.expand(),
  );

  @override
  Widget buildBlurDisabled() => const SizedBox.shrink();
}

class CachedBlurBackdrop extends StatefulWidget {
  final double sigma;
  final Widget child;

  const CachedBlurBackdrop({super.key, required this.sigma, required this.child});

  @override
  State<CachedBlurBackdrop> createState() => _CachedBlurBackdropState();
}

class _CachedBlurBackdropState extends _CachedBlurBackgroundState<CachedBlurBackdrop> {
  @override
  double get sigma => widget.sigma;

  @override
  FilterQuality get blitQuality => FilterQuality.medium;

  @override
  Widget buildBlurContent(Widget blurBackground) {
    return Stack(
      fit: StackFit.passthrough,
      children: [Positioned.fill(child: blurBackground), widget.child],
    );
  }

  @override
  Widget buildLiveBlur() => BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: widget.child,
  );

  @override
  Widget buildBlurDisabled() => widget.child;
}

abstract class _CachedBlurBackgroundState<T extends StatefulWidget> extends State<T> {
  ui.Image? _blurred;
  Size _builtSize = Size.zero;
  int _builtRevision = -1;
  String? _builtGradientId;
  double _builtSigma = -1;
  bool _building = false;

  @override
  void dispose() {
    _blurred?.dispose();
    super.dispose();
  }

  double get sigma;

  /// Upscale quality of the pre-blurred snapshot when it is blitted. The
  /// full-screen layer uses cheap bilinear sampling; the small dock blit can
  /// afford a filtered upscale.
  FilterQuality get blitQuality => FilterQuality.low;

  Widget buildBlurContent(Widget blurBackground);

  Widget buildLiveBlur();

  /// Rendered instead of a blur when blurring is switched off (video
  /// wallpaper with the blur-over-video toggle disabled).
  Widget buildBlurDisabled();

  /// The image the snapshot should be blurred: the current slideshow slide
  /// while a slideshow runs (the regular `wallpaper` provider is null then),
  /// otherwise the static wallpaper.
  ImageProvider? blurSource(WallpaperService service) {
    if (service.slideshowActive) {
      final slide = service.currentSlideshowFile;
      return slide != null ? FileImage(slide) : null;
    }
    return service.wallpaper;
  }

  Future<void> _build(WallpaperService service, Size size, double dpr) async {
    if (_building) return;
    _building = true;
    try {
      // A heavy GPU blur on the TV is the main cause of "slow" transitions, so
      // the snapshot is rendered at a quarter of the device pixel dimensions
      // (~16x cheaper to blur/store). The blit then upscales it — visually
      // indistinguishable because the content is already blurred.
      const snapshotScale = 0.25;
      final pxWidth = math.max(1, (size.width * dpr * snapshotScale).round());
      final pxHeight = math.max(1, (size.height * dpr * snapshotScale).round());
      final rect = Rect.fromLTWH(0, 0, pxWidth.toDouble(), pxHeight.toDouble());

      final provider = blurSource(service);
      ui.Image? source;
      if (provider != null) {
        // Cap the decode to the screen size: the raw FileImage resolves at
        // full photo resolution (a 12MP photo decodes to ~46MB) even though
        // the snapshot is only a quarter of that.
        final capped = ResizeImage(
          provider,
          height: (size.height * dpr).round(),
          allowUpscaling: false,
        );
        source = await _resolveImage(capped);
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final blurPaint =
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: sigma * dpr * snapshotScale,
              sigmaY: sigma * dpr * snapshotScale,
              tileMode: TileMode.clamp,
            );
      canvas.saveLayer(rect, blurPaint);
      if (source != null) {
        paintImage(canvas: canvas, rect: rect, image: source, fit: BoxFit.cover, filterQuality: FilterQuality.low);
      } else {
        canvas.drawRect(rect, Paint()..shader = service.gradient.gradient.createShader(rect));
      }
      canvas.restore();

      final image = await recorder.endRecording().toImage(pxWidth, pxHeight);
      source?.dispose();

      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _blurred?.dispose();
        _blurred = image;
        _builtSize = size;
        _builtRevision = service.wallpaperRevision;
        _builtGradientId = provider == null ? service.gradient.uuid : null;
        _builtSigma = sigma;
      });
    } finally {
      _building = false;
    }
  }

  Future<ui.Image> _resolveImage(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info.image);
      },
      onError: (error, stack) {
        stream.removeListener(listener);
        completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WallpaperService>();
    final settings = context.watch<SettingsService>();
    final videoFile = service.wallpaperVideoFile;
    if (videoFile != null) {
      // Video wallpapers are not static. The live per-frame blur is very
      // expensive on this GPU and made playback choppy, so it is only used
      // when explicitly enabled; otherwise the content shows unblurred.
      return settings.videoWallpaperBlurEnabled
          ? buildLiveBlur()
          : buildBlurDisabled();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final provider = blurSource(service);
        final gradientId = provider == null ? service.gradient.uuid : null;
        final stale =
            _blurred == null ||
            _builtSize != screen ||
            _builtRevision != service.wallpaperRevision ||
            _builtGradientId != gradientId ||
            _builtSigma != sigma;
        if (stale && screen.width > 0 && screen.height > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _build(service, screen, dpr);
          });
        }
        final image = _blurred;
        if (image == null || stale) {
          // Snapshot not ready: fall back to the live blur for correctness.
          return buildLiveBlur();
        }
        return buildBlurContent(_BlurBlit(image: image, screenSize: screen, filterQuality: blitQuality));
      },
    );
  }
}

/// Blits the region of the pre-blurred wallpaper [image] located under this
/// render box (in screen space) using the paint offset, so it stays aligned
/// with the wallpaper while scrolling.
class _BlurBlit extends LeafRenderObjectWidget {
  final ui.Image image;
  final Size screenSize;
  final FilterQuality filterQuality;

  const _BlurBlit({required this.image, required this.screenSize, this.filterQuality = FilterQuality.low});

  @override
  RenderObject createRenderObject(BuildContext context) => _BlurBlitRender(image, screenSize, filterQuality);

  @override
  void updateRenderObject(BuildContext context, _BlurBlitRender renderObject) {
    renderObject
      ..image = image
      ..screenSize = screenSize
      ..filterQuality = filterQuality;
  }
}

class _BlurBlitRender extends RenderBox {
  ui.Image _image;
  Size _screenSize;
  FilterQuality _filterQuality;

  _BlurBlitRender(this._image, this._screenSize, this._filterQuality);

  set image(ui.Image value) {
    if (value != _image) {
      _image = value;
      markNeedsPaint();
    }
  }

  set screenSize(Size value) {
    if (value != _screenSize) {
      _screenSize = value;
      markNeedsPaint();
    }
  }

  set filterQuality(FilterQuality value) {
    if (value != _filterQuality) {
      _filterQuality = value;
      markNeedsPaint();
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final scaleX = _image.width / _screenSize.width;
    final scaleY = _image.height / _screenSize.height;
    // Sample the blurred wallpaper at this box's true on-screen position so the
    // crop stays aligned with the real wallpaper (offset alone is layer-local).
    final screenPos = localToGlobal(Offset.zero);
    final src = Rect.fromLTWH(screenPos.dx * scaleX, screenPos.dy * scaleY, size.width * scaleX, size.height * scaleY);
    final dst = offset & size;
    context.canvas.drawImageRect(_image, src, dst, Paint()..filterQuality = _filterQuality);
  }
}
