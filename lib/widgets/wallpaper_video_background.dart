/*
 * FLauncher
 * Copyright (C) 2026 Meddouri Badis
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Video wallpaper rendered by a native platform view
/// (media3 ExoPlayer with decoder fallback in [VideoWallpaperPlatformView]).
/// The plain video_player plugin fails on some TVs whose hardware decoders
/// crash when initialized from Flutter's surface pipeline and offers no
/// software-decoder fallback.
class WallpaperVideoBackground extends StatelessWidget {
  const WallpaperVideoBackground({
    super.key,
    required this.file,
  });

  final File file;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: AndroidView(
          viewType: 'video_wallpaper_view',
          creationParams: <String, dynamic>{'path': file.path},
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }
}
