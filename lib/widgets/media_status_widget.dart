import 'dart:math' as math;

import 'package:flauncher/providers/media_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Now-playing controls for the status bar: album art, "Artist — Title",
/// previous / play-pause / next. Hidden automatically when no media session
/// is active.
class MediaStatusWidget extends StatelessWidget {
  const MediaStatusWidget({super.key});

  static const double _artSize = 28;

  @override
  Widget build(BuildContext context) {
    return Selector<MediaService, MediaSessionInfo?>(
      selector: (_, media) => media.activeSession,
      builder: (context, session, _) {
        if (session == null) {
          return const SizedBox.shrink();
        }

        final textStyle = TextStyle(
          color: Colors.white,
          fontSize: 14,
          shadows: const [
            Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8)
          ],
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _albumArt(session),
            const SizedBox(width: 8),
            ConstrainedBox(
              // Keep the title from pushing the clock off-screen.
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                session.subtitle.isEmpty ? '' : session.subtitle,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            _transportButton(
              icon: Icons.skip_previous,
              tooltip: 'Previous',
              enabled: session.supportsPrevious,
              onPressed: () => context.read<MediaService>().previous(),
            ),
            _transportButton(
              icon: session.isPlaying ? Icons.pause : Icons.play_arrow,
              tooltip: session.isPlaying ? 'Pause' : 'Play',
              enabled: true,
              onPressed: () => context.read<MediaService>().togglePlayPause(),
            ),
            _transportButton(
              icon: Icons.skip_next,
              tooltip: 'Next',
              enabled: session.supportsNext,
              onPressed: () => context.read<MediaService>().next(),
            ),
          ],
        );
      },
    );
  }

  Widget _albumArt(MediaSessionInfo session) {
    final bytes = session.artBytes;
    if (bytes == null) {
      return const Icon(Icons.music_note, color: Colors.white, size: _artSize - 4);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.memory(
        bytes,
        width: _artSize,
        height: _artSize,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.music_note,
          color: Colors.white,
          size: _artSize - 4,
        ),
      ),
    );
  }

  Widget _transportButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? Colors.white : Colors.white38,
            shadows: const [
              Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8)
            ],
          ),
        ),
      ),
    );
  }
}

/// Small progress bar under the status-bar media row.
class MediaProgressBar extends StatelessWidget {
  const MediaProgressBar({super.key});

  static const double _width = 220;

  @override
  Widget build(BuildContext context) {
    return Selector<MediaService, (int, int, bool)>(
      selector: (_, media) {
        final session = media.activeSession;
        if (session == null) return (0, 0, false);
        return (session.positionMs, session.durationMs, session.isPlaying);
      },
      builder: (context, data, _) {
        final (position, duration, _) = data;
        if (duration <= 0) return const SizedBox.shrink();
        final value = (math.min(position, duration) / duration).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SizedBox(
            width: _width,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}
