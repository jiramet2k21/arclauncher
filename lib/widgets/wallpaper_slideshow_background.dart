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

import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen wallpaper that crossfades between the images of a slideshow.
///
/// The rotation itself is owned by [WallpaperService]; this widget only reacts
/// to index changes and animates the transition. The next image is pre-cached
/// on every update so the crossfade never stalls on a cold decode.
class WallpaperSlideshowBackground extends StatefulWidget {
  final List<File> files;
  final int index;
  final int imageHeight;

  const WallpaperSlideshowBackground({
    super.key,
    required this.files,
    required this.index,
    required this.imageHeight,
  });

  @override
  State<WallpaperSlideshowBackground> createState() =>
      _WallpaperSlideshowBackgroundState();
}

class _WallpaperSlideshowBackgroundState
    extends State<WallpaperSlideshowBackground> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.files.length < 2) return;
      precacheImage(
        ResizeImage(
          FileImage(widget.files[1]),
          height: widget.imageHeight,
          allowUpscaling: false,
        ),
        context,
      );
    });
  }

  @override
  void didUpdateWidget(covariant WallpaperSlideshowBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.files.isEmpty) return;
    final nextIndex = (widget.index + 1) % widget.files.length;
    precacheImage(
      ResizeImage(
        FileImage(widget.files[nextIndex]),
        height: widget.imageHeight,
        allowUpscaling: false,
      ),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return const SizedBox.shrink();
    }
    final safeIndex = widget.index % widget.files.length;
    final file = widget.files[safeIndex];
    return SizedBox.expand(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        child: Image(
          key: ValueKey('slide_${safeIndex}_${file.path}'),
          image: ResizeImage(
            FileImage(file),
            height: widget.imageHeight,
            allowUpscaling: false,
          ),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
