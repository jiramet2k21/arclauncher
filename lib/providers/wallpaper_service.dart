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
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

class WallpaperService extends ChangeNotifier {
  final Random _random = Random();
  final SettingsService _settingsService;
  final FLauncherChannel _channel = FLauncherChannel();

  late File _wallpaperFile;
  late File _wallpaperDayFile;
  late File _wallpaperNightFile;
  late File _wallpaperVideoFile;
  late File _wallpaperDayVideoFile;
  late File _wallpaperNightVideoFile;
  bool _initialized = false;
  Timer? _timer;
  int _wallpaperRevision = 0;

  bool _lastSlideshowEnabled = false;
  int _lastSlideshowInterval = 30;
  List<File> _slideshowFiles = [];
  int _slideshowIndex = 0;
  Timer? _slideshowTimer;

  ImageProvider? _wallpaper;
  int get wallpaperRevision => _wallpaperRevision;

  ImageProvider? get wallpaper => _wallpaper;

  bool get slideshowActive =>
      _settingsService.slideshowEnabled && _slideshowFiles.isNotEmpty;

  List<File> get slideshowFiles => List.unmodifiable(_slideshowFiles);

  int get slideshowIndex => _slideshowIndex;

  File? get wallpaperVideoFile {
    final f = _resolveActiveVideoFile();
    return f != null && f.existsSync() ? f : null;
  }

  FLauncherGradient get gradient => FLauncherGradients.all.firstWhere(
    (gradient) => gradient.uuid == _settingsService.gradientUuid,
    orElse: () => FLauncherGradients.saintPetersburg,
  );

  WallpaperService(this._settingsService) : _wallpaper = null {
    _settingsService.addListener(_onSettingsChanged);
    _init();
  }

  bool _lastTimeBasedEnabled = false;

  void _onSettingsChanged() {
    final enabled = _settingsService.timeBasedWallpaperEnabled;
    if (enabled != _lastTimeBasedEnabled) {
      _lastTimeBasedEnabled = enabled;
      _updateTimerState();
      _updateWallpaper();
    }

    final slideshowEnabled = _settingsService.slideshowEnabled;
    final slideshowInterval = _settingsService.slideshowIntervalSeconds;
    if (slideshowEnabled != _lastSlideshowEnabled) {
      _lastSlideshowEnabled = slideshowEnabled;
      _lastSlideshowInterval = slideshowInterval;
      if (slideshowEnabled) {
        _startSlideshowFromSettings();
      } else {
        stopSlideshow();
      }
      _updateWallpaper(force: true);
    } else if (slideshowInterval != _lastSlideshowInterval) {
      _lastSlideshowInterval = slideshowInterval;
      if (slideshowActive) {
        _restartSlideshowTimer();
      }
    }
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _timer?.cancel();
    _slideshowTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    _wallpaperFile = File("${directory.path}/wallpaper");
    _wallpaperDayFile = File("${directory.path}/wallpaper_day");
    _wallpaperNightFile = File("${directory.path}/wallpaper_night");
    _wallpaperVideoFile = File("${directory.path}/wallpaper_video");
    _wallpaperDayVideoFile = File("${directory.path}/wallpaper_day_video");
    _wallpaperNightVideoFile = File("${directory.path}/wallpaper_night_video");
    _initialized = true;

    _lastTimeBasedEnabled = _settingsService.timeBasedWallpaperEnabled;
    _lastSlideshowEnabled = _settingsService.slideshowEnabled;
    _lastSlideshowInterval = _settingsService.slideshowIntervalSeconds;
    _updateWallpaper();
    _updateTimerState();
    if (_lastSlideshowEnabled) {
      _startSlideshowFromSettings();
    }
  }

  void _updateTimerState() {
    final enabled = _settingsService.timeBasedWallpaperEnabled;
    if (enabled && (_timer == null || !_timer!.isActive)) {
      _timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _updateWallpaper(),
      );
    } else if (!enabled && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  File? _resolveActiveVideoFile() {
    if (!isInitialized) return null;

    final now = DateTime.now();
    final isDay = now.hour >= 6 && now.hour < 18;
    final enabled = _settingsService.timeBasedWallpaperEnabled;

    if (enabled) {
      if (isDay && _wallpaperDayVideoFile.existsSync()) {
        return _wallpaperDayVideoFile;
      }
      if (!isDay && _wallpaperNightVideoFile.existsSync()) {
        return _wallpaperNightVideoFile;
      }
      if (_wallpaperVideoFile.existsSync()) {
        return _wallpaperVideoFile;
      }
    } else if (_wallpaperVideoFile.existsSync()) {
      return _wallpaperVideoFile;
    }
    return null;
  }

  bool get isInitialized => _initialized;

  void _updateWallpaper({bool force = false}) {
    final now = DateTime.now();
    final isDay = now.hour >= 6 && now.hour < 18;
    final enabled = _settingsService.timeBasedWallpaperEnabled;

    final videoFile = _resolveActiveVideoFile();

    ImageProvider? newWallpaper;

    if (videoFile != null) {
      newWallpaper = null;
    } else if (enabled) {
      if (isDay && _wallpaperDayFile.existsSync()) {
        newWallpaper = FileImage(_wallpaperDayFile);
      } else if (!isDay && _wallpaperNightFile.existsSync()) {
        newWallpaper = FileImage(_wallpaperNightFile);
      } else if (_wallpaperFile.existsSync()) {
        newWallpaper = FileImage(_wallpaperFile); // Fallback
      }
    } else if (_wallpaperFile.existsSync()) {
      newWallpaper = FileImage(_wallpaperFile);
    }

    if (_wallpaper != newWallpaper || videoFile != null || force) {
      _wallpaper = newWallpaper;
      _wallpaperRevision++;
      notifyListeners();
    }
  }

  Future<void> pickWallpaper(File sourceFile) async {
    await _saveImage(sourceFile, _wallpaperFile);
  }

  Future<void> pickWallpaperFromUri(String sourceUri) async {
    await _saveImageBytes(
      await _channel.loadContentUriImage(sourceUri),
      _wallpaperFile,
    );
  }

  Future<void> pickWallpaperDay(File sourceFile) async {
    await _saveImage(sourceFile, _wallpaperDayFile);
  }

  Future<void> pickWallpaperDayFromUri(String sourceUri) async {
    await _saveImageBytes(
      await _channel.loadContentUriImage(sourceUri),
      _wallpaperDayFile,
    );
  }

  Future<void> pickWallpaperNight(File sourceFile) async {
    await _saveImage(sourceFile, _wallpaperNightFile);
  }

  Future<void> pickWallpaperNightFromUri(String sourceUri) async {
    await _saveImageBytes(
      await _channel.loadContentUriImage(sourceUri),
      _wallpaperNightFile,
    );
  }

  Future<void> pickVideoWallpaper(String? mediaUri, File sourceFile) async {
    await _saveVideo(mediaUri, sourceFile, _wallpaperVideoFile);
  }

  Future<void> pickVideoWallpaperDay(String? mediaUri, File sourceFile) async {
    await _saveVideo(mediaUri, sourceFile, _wallpaperDayVideoFile);
  }

  Future<void> pickVideoWallpaperNight(String? mediaUri, File sourceFile) async {
    await _saveVideo(mediaUri, sourceFile, _wallpaperNightVideoFile);
  }

  Future<void> _saveImage(File sourceFile, File targetFile) async {
    await _deactivateSlideshow();
    await _replacePairedVideo(targetFile);

    final readStream = sourceFile.openRead();
    final writeStream = targetFile.openWrite();
    await readStream.cast<List<int>>().pipe(writeStream);

    await _refreshImageWallpaper(targetFile);
  }

  Future<void> _saveImageBytes(Uint8List imageBytes, File targetFile) async {
    if (imageBytes.isEmpty) {
      throw StateError('Unable to read the selected image');
    }

    await _deactivateSlideshow();
    await _replacePairedVideo(targetFile);
    await targetFile.writeAsBytes(imageBytes, flush: true);

    await _refreshImageWallpaper(targetFile);
  }

  Future<void> _replacePairedVideo(File targetFile) async {
    // Setting an image means the user no longer wants a video wallpaper, so
    // remove all video wallpaper files (including unrelated ones like the
    // general wallpaper_video when setting wallpaper_day) to prevent stale
    // video playback after switching.
    await cleanVideoWallpaperFiles();
  }

  Future<void> _refreshImageWallpaper(File targetFile) async {
    await FileImage(targetFile).evict();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    _updateWallpaper(force: true);
  }

  Future<void> _saveVideo(String? mediaUri, File sourceFile, File targetVideoFile) async {
    await _deactivateSlideshow();
    final pairedImage = _pairedImageForVideo(targetVideoFile);
    if (pairedImage != null && await pairedImage.exists()) {
      await pairedImage.delete();
    }

    // Prefer reading through the content:// URI: on Android 11 scoped storage
    // a direct File(path) read of a MediaStore row often fails silently.
    bool saved = false;
    if (mediaUri != null && mediaUri.isNotEmpty) {
      final bytes = await _channel.loadContentUriVideoBytes(mediaUri);
      if (bytes.isNotEmpty) {
        await targetVideoFile.writeAsBytes(bytes, flush: true);
        saved = true;
      }
    }
    if (!saved) {
      final readStream = sourceFile.openRead();
      final writeStream = targetVideoFile.openWrite();
      await readStream.cast<List<int>>().pipe(writeStream);
    }

    _updateWallpaper(force: true);
  }

  File? _pairedImageForVideo(File videoFile) {
    if (videoFile.path == _wallpaperVideoFile.path) return _wallpaperFile;
    if (videoFile.path == _wallpaperDayVideoFile.path) return _wallpaperDayFile;
    if (videoFile.path == _wallpaperNightVideoFile.path)
      return _wallpaperNightFile;
    return null;
  }

  Future<void> startSlideshowFromBucket(String bucketId, {String? folderName}) async {
    const maxImages = 100;
    final images = await _channel.getMediaStoreImagesInBucket(bucketId);

    final directory = await getApplicationDocumentsDirectory();
    final slideshowDir = Directory("${directory.path}/slideshow");
    if (await slideshowDir.exists()) {
      await slideshowDir.delete(recursive: true);
    }
    await slideshowDir.create(recursive: true);

    final files = <File>[];
    for (final entry in images) {
      if (files.length >= maxImages) break;
      final path = entry['path'] as String?;
      if (path == null) continue;
      final source = File(path);
      if (!await source.exists()) continue;
      final dotIndex = path.lastIndexOf('.');
      final extension = dotIndex >= 0 ? path.substring(dotIndex) : '.jpg';
      final target = File(
        "${slideshowDir.path}/${files.length.toString().padLeft(5, '0')}$extension",
      );
      await source.copy(target.path);
      files.add(target);
    }

    if (files.isEmpty) {
      throw StateError('No images found in the selected folder');
    }

    await cleanImageWallpaperFiles();
    await cleanVideoWallpaperFiles();
    await _settingsService.setSlideshowFolderName(folderName ?? bucketId);

    _slideshowFiles = files..shuffle(_random);
    _slideshowIndex = 0;
    _restartSlideshowTimer();
    _updateWallpaper(force: true);
  }

  Future<void> _startSlideshowFromSettings() async {
    final directory = await getApplicationDocumentsDirectory();
    final slideshowDir = Directory("${directory.path}/slideshow");
    if (await slideshowDir.exists()) {
      final entries = await slideshowDir.list().toList();
      final files = entries.whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path))
        ..shuffle(_random);
      _slideshowFiles = files;
    } else {
      _slideshowFiles = [];
    }
    _slideshowIndex = 0;
    _restartSlideshowTimer();
    notifyListeners();
  }

  void _restartSlideshowTimer() {
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    if (slideshowActive && _slideshowFiles.length > 1) {
      _slideshowTimer = Timer.periodic(
        Duration(seconds: _settingsService.slideshowIntervalSeconds),
        (_) {
          final nextIndex = _slideshowIndex + 1;
          if (nextIndex < _slideshowFiles.length) {
            _slideshowIndex = nextIndex;
          } else {
            // Every photo has been shown once: start a fresh cycle from a new
            // shuffle, making sure the first image differs from the last one
            // shown so no photo plays back-to-back across cycles.
            final lastShown = _slideshowFiles[_slideshowIndex];
            final shuffled = List.of(_slideshowFiles)..shuffle(_random);
            if (_slideshowFiles.length > 1 && shuffled.first.path == lastShown.path) {
              final swapIndex = 1 + _random.nextInt(_slideshowFiles.length - 1);
              final tmp = shuffled[0];
              shuffled[0] = shuffled[swapIndex];
              shuffled[swapIndex] = tmp;
            }
            _slideshowFiles = shuffled;
            _slideshowIndex = 0;
          }
          _wallpaperRevision++;
          notifyListeners();
        },
      );
    }
  }

  Future<void> stopSlideshow() async {
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    _slideshowFiles = [];
    _slideshowIndex = 0;
    _updateWallpaper(force: true);
  }

  Future<void> _deactivateSlideshow() async {
    if (_slideshowFiles.isEmpty && !_settingsService.slideshowEnabled) return;
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    _slideshowFiles = [];
    _slideshowIndex = 0;
    if (_settingsService.slideshowEnabled) {
      await _settingsService.setSlideshowEnabled(false);
    }
  }

  Future<void> setGradient(FLauncherGradient fLauncherGradient) async {
    await _deactivateSlideshow();
    await cleanImageWallpaperFiles();
    await cleanVideoWallpaperFiles();

    await _settingsService.setGradientUuid(fLauncherGradient.uuid);
    // Drop the in-memory wallpaper provider so the gradient is shown instead of
    // the (now deleted) image/video file. _updateWallpaper notifies listeners.
    _updateWallpaper(force: true);
  }

  // Cleaning methods

  Future<void> cleanVideoWallpaperFiles() async {
    if (await _wallpaperVideoFile.exists()) {
      await _wallpaperVideoFile.delete();
    }

    if (await _wallpaperDayVideoFile.exists()) {
      await _wallpaperDayVideoFile.delete();
    }

    if (await _wallpaperNightVideoFile.exists()) {
      await _wallpaperNightVideoFile.delete();
    }
  }

  Future<void> cleanImageWallpaperFiles() async {
    if (await _wallpaperFile.exists()) {
      await _wallpaperFile.delete();
    }

    if (await _wallpaperDayFile.exists()) {
      await _wallpaperDayFile.delete();
    }

    if (await _wallpaperNightFile.exists()) {
      await _wallpaperNightFile.delete();
    }
  }
}
