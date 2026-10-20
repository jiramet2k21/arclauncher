/*
 * Arc Launcher — media session bridge
 *
 * Surfaces whatever the device is currently playing (Spotify, YouTube Music,
 * any app exposing a MediaSession) in the status bar. The native
 * NotificationListenerService feeds us the session list; this provider keeps
 * it in a Flutter-friendly shape and handles transport commands.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flauncher/flauncher_channel.dart';

/// One active media session.
@immutable
class MediaSessionInfo {
  final String packageName;
  final String? title;
  final String? artist;
  final String? album;
  final Uint8List? artBytes;
  final int durationMs;
  final int positionMs;
  final bool isPlaying;
  final bool supportsNext;
  final bool supportsPrevious;

  const MediaSessionInfo({
    required this.packageName,
    this.title,
    this.artist,
    this.album,
    this.artBytes,
    this.durationMs = 0,
    this.positionMs = 0,
    this.isPlaying = false,
    this.supportsNext = false,
    this.supportsPrevious = false,
  });

  factory MediaSessionInfo.fromMap(Map<String, dynamic> map) {
    final art = map['artBytes'];
    return MediaSessionInfo(
      packageName: map['packageName'] as String? ?? '',
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      artBytes: art is Uint8List && art.isNotEmpty ? art : null,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      isPlaying: map['isPlaying'] as bool? ?? false,
      supportsNext: map['supportsNext'] as bool? ?? false,
      supportsPrevious: map['supportsPrevious'] as bool? ?? false,
    );
  }

  /// "Artist — Title" or whatever is available; empty when nothing usable.
  String get subtitle {
    final parts = <String>[
      if (artist != null && artist!.isNotEmpty) artist!,
      if (title != null && title!.isNotEmpty) title!,
    ];
    return parts.join(' — ');
  }

  bool get hasMetadata =>
      (title != null && title!.isNotEmpty) ||
      (artist != null && artist!.isNotEmpty);

  MediaSessionInfo copyWith({
    int? positionMs,
    bool? isPlaying,
  }) {
    return MediaSessionInfo(
      packageName: packageName,
      title: title,
      artist: artist,
      album: album,
      artBytes: artBytes,
      durationMs: durationMs,
      positionMs: positionMs ?? this.positionMs,
      isPlaying: isPlaying ?? this.isPlaying,
      supportsNext: supportsNext,
      supportsPrevious: supportsPrevious,
    );
  }
}

class MediaService extends ChangeNotifier {
  final FLauncherChannel _fLauncherChannel;

  List<MediaSessionInfo> _sessions = [];
  bool _listenerEnabled = false;
  Timer? _positionTimer;
  Timer? _permissionTimer;

  /// Index into [_sessions] of the session shown in the status bar.
  int _selectedIndex = 0;

  MediaService(this._fLauncherChannel) {
    _init();
  }

  void _init() {
    _fLauncherChannel.addMediaChangedListener(_onSessionsChanged);
    _refreshListenerState();
    // Notification access can be granted while we're in the background;
    // poll it back in without waiting for a resume.
    _permissionTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _refreshListenerState());
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _permissionTimer?.cancel();
    super.dispose();
  }

  void _onSessionsChanged(List<Map<String, dynamic>> raw) {
    final sessions = raw.map(MediaSessionInfo.fromMap).toList();
    if (listEquals(sessions, _sessions)) return;
    _sessions = sessions;
    if (_selectedIndex >= _sessions.length) {
      _selectedIndex = 0;
    }
    _updatePositionTimer();
    notifyListeners();
  }

  /// Ticks the progress of the playing session so the UI stays honest without
  /// hammering the platform channel.
  void _updatePositionTimer() {
    final playing = activeSession?.isPlaying ?? false;
    if (playing && _positionTimer == null) {
      _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final session = activeSession;
        if (session == null || !session.isPlaying) {
          _positionTimer?.cancel();
          _positionTimer = null;
          return;
        }
        final next = session.positionMs + 1000;
        if (next >= session.durationMs && session.durationMs > 0) {
          _positionTimer?.cancel();
          _positionTimer = null;
        }
        _sessions[_selectedIndex] = session.copyWith(
          positionMs: session.durationMs > 0 && next > session.durationMs
              ? session.durationMs
              : next,
        );
        notifyListeners();
      });
    } else if (!playing && _positionTimer != null) {
      _positionTimer?.cancel();
      _positionTimer = null;
    }
  }

  Future<void> _refreshListenerState() async {
    final enabled = await _fLauncherChannel.isNotificationListenerEnabled();
    if (enabled != _listenerEnabled) {
      _listenerEnabled = enabled;
      notifyListeners();
    }
  }

  /// Called when the launcher resumes — the user may have just granted access.
  Future<void> refresh() async {
    await _refreshListenerState();
    final sessions = await _fLauncherChannel.getActiveMediaSessions();
    _onSessionsChanged(sessions);
  }

  List<MediaSessionInfo> get sessions => List.unmodifiable(_sessions);

  bool get listenerEnabled => _listenerEnabled;

  bool get hasSession => _sessions.isNotEmpty;

  /// The session shown in the status bar (null when nothing is playing).
  MediaSessionInfo? get activeSession =>
      _sessions.isEmpty ? null : _sessions[_selectedIndex];

  /// Cycles which session is displayed, for the rare multi-app case.
  void selectSession(int index) {
    if (index < 0 || index >= _sessions.length || index == _selectedIndex) return;
    _selectedIndex = index;
    _updatePositionTimer();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    final session = activeSession;
    if (session == null) return;
    await _fLauncherChannel.mediaTransport(session.packageName, 'playPause');
  }

  Future<void> next() async {
    final session = activeSession;
    if (session == null) return;
    await _fLauncherChannel.mediaTransport(session.packageName, 'next');
  }

  Future<void> previous() async {
    final session = activeSession;
    if (session == null) return;
    await _fLauncherChannel.mediaTransport(session.packageName, 'previous');
  }

  Future<void> openListenerSettings() =>
      _fLauncherChannel.openNotificationListenerSettings();
}
