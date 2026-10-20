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

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/tv_media_picker.dart';
import 'package:flauncher/widgets/tv_folder_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'package:flauncher/widgets/rounded_switch_list_tile.dart';

class WallpaperPanelPage extends StatelessWidget {
  static const String routeName = "wallpaper_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(
          localizations.wallpaper,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Divider(),
        Consumer<SettingsService>(
          builder: (_, settings, __) {
            return RoundedSwitchListTile(
              title: Text(localizations.timeBasedWallpaper),
              secondary: Icon(Icons.access_time),
              value: settings.timeBasedWallpaperEnabled,
              onChanged: (value) {
                settings.setTimeBasedWallpaperEnabled(value);
                if (value) settings.setSlideshowEnabled(false);
              },
            );
          },
        ),
        Consumer<SettingsService>(
          builder: (_, settings, __) {
            return RoundedSwitchListTile(
              title: Text(localizations.slideshow),
              secondary: Icon(Icons.slideshow),
              value: settings.slideshowEnabled,
              onChanged: (value) {
                settings.setSlideshowEnabled(value);
                if (value) settings.setTimeBasedWallpaperEnabled(false);
              },
            );
          },
        ),
        Consumer<SettingsService>(
          builder: (_, settings, __) {
            if (settings.timeBasedWallpaperEnabled) {
              return Column(
                children: [
                  FocusableSettingsTile(
                    leading: Icon(Icons.wb_sunny),
                    title: Text(localizations.pickDayWallpaper),
                    onPressed: () => _pickWallpaper(
                      context,
                      (s, media) => s.pickWallpaperDayFromUri(media.uri),
                      false,
                    ),
                  ),
                  FocusableSettingsTile(
                    leading: Icon(Icons.videocam_outlined),
                    title: Text(localizations.pickDayVideoWallpaper),
                    onPressed: () => _pickWallpaper(
                      context,
                      (s, media) => s.pickVideoWallpaperDay(media.uri, File(media.path)),
                      true,
                    ),
                  ),
                  FocusableSettingsTile(
                    leading: Icon(Icons.nights_stay),
                    title: Text(localizations.pickNightWallpaper),
                    onPressed: () => _pickWallpaper(
                      context,
                      (s, media) => s.pickWallpaperNightFromUri(media.uri),
                      false,
                    ),
                  ),
                  FocusableSettingsTile(
                    leading: Icon(Icons.videocam_outlined),
                    title: Text(localizations.pickNightVideoWallpaper),
                    onPressed: () => _pickWallpaper(
                      context,
                      (s, media) => s.pickVideoWallpaperNight(media.uri, File(media.path)),
                      true,
                    ),
                  ),
                ],
              );
            } else if (settings.slideshowEnabled) {
              return Column(
                children: [
                  FocusableSettingsTile(
                    autofocus: true,
                    leading: Icon(Icons.timelapse),
                    title: Text(localizations.slideshowInterval),
                    trailing: Text(_formatInterval(settings.slideshowIntervalSeconds)),
                    onPressed: () => _pickSlideshowInterval(context),
                  ),
                  FocusableSettingsTile(
                    leading: Icon(Icons.folder),
                    title: Text(localizations.slideshowFolder),
                    trailing: Text(
                      settings.slideshowFolderName ?? localizations.slideshowNoFolder,
                    ),
                    onPressed: () => _pickSlideshowFolder(context),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  FocusableSettingsTile(
                    autofocus: true,
                    leading: Icon(Icons.gradient),
                    title: Text(
                      localizations.gradient,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(GradientPanelPage.routeName),
                  ),
                  FocusableSettingsTile(
                    leading: Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      localizations.picture,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    onPressed: () => _pickWallpaper(
                      context,
                      (s, media) => s.pickWallpaperFromUri(media.uri),
                      false,
                    ),
                  ),
                  FocusableSettingsTile(
                    leading: Icon(Icons.videocam_outlined),
                    title: Text(
                      localizations.video,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    onPressed: () => _pickWallpaper(
                      context,
                      (s, media) => s.pickVideoWallpaper(media.uri, File(media.path)),
                      true,
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _pickSlideshowInterval(BuildContext context) async {
    final settings = context.read<SettingsService>();
    const options = [15, 30, 60, 300];
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Slideshow interval'),
        children: options
            .map(
              (seconds) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(seconds),
                child: Text(_formatInterval(seconds)),
              ),
            )
            .toList(),
      ),
    );
    if (choice != null) {
      await settings.setSlideshowIntervalSeconds(choice);
    }
  }

  Future<void> _pickSlideshowFolder(BuildContext context) async {
    final folder = await TvFolderPicker.show(context);
    if (folder == null || !context.mounted) return;
    try {
      await context.read<WallpaperService>().startSlideshowFromBucket(
            folder.id,
            folderName: folder.name,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No images found in the selected folder'),
          ),
        );
      }
    }
  }

  String _formatInterval(int seconds) {
    if (seconds < 60) return '$seconds s';
    final minutes = seconds ~/ 60;
    return '$minutes min';
  }

  Future<void> _pickWallpaper(
    BuildContext context,
    Future<void> Function(WallpaperService, TvMediaSelection) action,
    bool isVideo,
  ) async {
    final media = await TvMediaPicker.show(
      context,
      mode: isVideo ? TvMediaPickerMode.video : TvMediaPickerMode.image,
    );
    if (media == null || !context.mounted) return;
    try {
      await action(context.read<WallpaperService>(), media);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVideo
                  ? 'Could not load the selected video'
                  : 'Could not load the selected image',
            ),
          ),
        );
      }
    }
  }
}
