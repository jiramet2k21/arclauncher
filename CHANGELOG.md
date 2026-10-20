# Changes from the original

### Features
* Allow users to customize the date widget format, making it possible to display the [date, time](https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html), and any arbitrary text, or to hide it completely.
* Choose what the back button does while being in the launcher: Nothing, Show a fullscreen clock, Show screensaver (a.k.a Ambient Mode).
* Show the active network status next to the date widget.
* Allow users to hide the application category titles.
* Clicking or tapping on an application card now opens it.
* Ability to disable the navigation keys sound.
* The app bar can now hide automatically while not focused.
* Map "Escape" key to the "Back" action.
* Translate to Spanish.

### Removals
* Firebase analytics and crashlytics services.
* Unsplash integration.

### Misc
* Upgrade Flutter version from 3.7.5 to 3.24.5.
* Replace Kotlin code with Java.
* Set new language versions: Java (17), Dart (greater than or equal to 3.4.3).
* Change versioning scheme to \<year>.\<month>.\<monthly release number>

---

# Changes in this fork (`jiramet2k21/arclauncher`)

Personal fork of Arc Launcher for a TCL Google TV (Android 11, Realtek-class
chipset). The focus is **performance on low-end TV hardware** and making the
features Arc Launcher already advertises actually work on this box. Every item
below was verified on the device.

## Performance fixes

* **Picture picker no longer freezes or reboots the TV.** The picker used to
  decode every grid thumbnail at full resolution (~35 live 12 MP bitmaps ≈ 1.9 GB
  → native OOM → the always-running HOME process died → watchdog reboot).
  Thumbnails now come from a native `ContentResolver.loadThumbnail()` call
  (mirroring the existing video branch) with a `cacheWidth` decode cap, the
  serial `File.exists()` loop is gone, and the scroll-to-focus math is fixed.
* **Blur cost cut ~16×.** The cached-blur snapshot is now rendered at 0.25×
  device pixels and blitted with `FilterQuality.low` (the dock blit keeps
  `medium`), and the snapshot source is wrapped in `ResizeImage` so the
  full-resolution bitmap is never decoded.
* **Wallpaper decode is capped** to screen dimensions on every site
  (`allowUpscaling: false`).
* **Video wallpaper no longer stutters.** Two separate causes fixed: the dock
  blur used to run a *live* `BackdropFilter` over the video on every frame
  (now a toggle, default off), and the wallpaper video itself is played by a
  native media3 platform view instead of the `video_player` plugin — the Realtek
  hardware decoder fails to initialise through Flutter's GL texture pipeline
  (`OMX.realtek.video.decoder … start failed`), while the platform view works.
* **Perf pack:** the active video file is cached instead of `stat()`-ing on
  every build; `layoutVersion` was removed from the rebuild selector so package
  events no longer rebuild the whole scroll view; the dock has its own
  `RepaintBoundary`; `AppCard`'s repaint boundary now wraps the outside of the
  scale transforms (so it actually caches); the Wi-Fi usage future is hoisted
  out of `build`.

## Features

* **Background blur during a slideshow.** The blur layer was explicitly
  disabled while a slideshow ran; it now snapshots the current slide and follows
  focus.
* **Slideshow order:** shuffle (default, no repeats until every photo has shown)
  or sequential folder order — selectable in the wallpaper settings.
* **Clock & date sizing/typeface:** 3 sizes (20/28/40) — the date follows the
  clock size — plus 6 font styles (Default, Bold, Monospace, Serif, Condensed,
  Glow).
* **Media controls in the status bar:** now-playing art, title/artist and
  prev/play/next for any app with a media session (Spotify, YouTube Music, …)
  via a native `MediaSessionListenerService`.
* **macOS-style dock magnification** (focused icon 1.25, neighbours tapering to
  1.10/1.00 and far icons 0.92) with a highlight box that *slides* between
  icons, plus selectable highlight sizes and a status-bar gradient scrim.
* **Open-app animation** with 4 selectable styles (Zoom, Page flip, Pulse,
  Circle) and a configurable start delay (1/2/3 s, counted concurrently with
  the animation).

## Fixes

* Video wallpaper selection failed silently under scoped storage; the copy is
  now URI-based with an error SnackBar and a playback-error fallback.
* The status-bar date and clock are now baseline-aligned (the date used to sit
  visibly lower).
* Dock focus no longer scrolls the viewport as if Down was pressed (the
  magnified icon's bottom edge used to move the reveal target).
* The signing keystore is committed to the repo, so updates install **in place**
  (`adb install -r`) instead of wiping app data on every release.

## Removals

* Nothing removed. (This fork keeps the `video_player` dependency but no longer
  uses it for the wallpaper.)

## TCL Google TV notes

* Media controls need two one-time grants (they are wiped on every app update):
  `adb shell appops set com.omeda.arc APP_AUTO_START allow` then
  `adb shell cmd notification allow_listener com.omeda.arc/.MediaSessionListenerService 0`.
  The first is required because the firmware's app-boot manager refuses to bind
  services for apps without the auto-start app op; there is no notification
  access UI anywhere in the TV settings.
