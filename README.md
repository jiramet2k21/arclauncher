# Arc Launcher (jiramet2k21 fork)

<p align="center">
  <img alt="Arc Launcher Preview" src="docs/images/home.webp" width="80%">
</p>

[![Build](https://img.shields.io/github/actions/workflow/status/jiramet2k21/arclauncher/.github/workflows/build.yml?style=for-the-badge&label=Build)](https://github.com/jiramet2k21/arclauncher/actions) [![Release](https://img.shields.io/github/v/release/jiramet2k21/arclauncher?style=for-the-badge&color=7C4DFF&label=Release)](https://github.com/jiramet2k21/arclauncher/releases/latest)

**A fork of [Arc Launcher](https://github.com/meddouribadis/arclauncher) tuned for a TCL Google TV (Android 11, Realtek-class chipset).**

The goal of this fork is simple: make the launcher *fast and reliable on a
low-end TV box*, and make the features the upstream README advertises actually
work on this hardware. If you run Arc Launcher on a similar budget Android TV
device, the fixes here are likely useful to you too.

Notable work in this fork (all verified on the device — see
[CHANGELOG.md](CHANGELOG.md) for the full list):

- **Picture picker no longer freezes or reboots the TV** — thumbnails are
  generated natively and decoded at tile size instead of full resolution.
- **Video wallpaper works and plays smoothly** — the Realtek hardware decoder
  fails inside Flutter's `video_player` pipeline, so the wallpaper is played by
  a native media3 platform view instead.
- **Background blur during a slideshow**, blur cost cut ~16×, and a
  "blur over video" toggle so video stays smooth.
- **Media controls in the status bar** (Spotify / YouTube Music / any media
  session): art, title, artist, prev / play / next.
- **macOS-style dock magnification** with a sliding highlight, plus selectable
  highlight sizes and a status-bar gradient scrim.
- **Clock & date sizing and typeface** (20/28/40 px; Default / Bold /
  Monospace / Serif / Condensed / Glow).
- **Slideshow shuffle** (no repeats until every photo has shown) or sequential.
- **Open-app animation** with 4 styles and a 1/2/3 s start delay setting.
- **Stable signing key** in the repo, so updates install in place with
  `adb install -r` instead of wiping app data.

## Download

Grab the latest APK from
[Releases](https://github.com/jiramet2k21/arclauncher/releases/latest).

| Variant | Use |
| --- | --- |
| `arc-launcher-armeabi-v7a-release.apk` | 32-bit TVs (most Android TV boxes, incl. the TCL this fork targets) |
| `arc-launcher-arm64-v8a-release.apk` | 64-bit devices |
| `arc-launcher-universal-release.apk` | Both ABIs in one APK |

Install over an existing install (data is preserved):

```shell
$ adb install -r arc-launcher-armeabi-v7a-release.apk
```

## Key Features & Enhancements

Inherited from Arc Launcher:

- **Modern TV Layout** - Redesigned home screen inspired by premium smart TV interfaces.
- **Data Usage Widget** - Track daily Internet consumption directly from the status bar.
- **Inbuilt OLED Screensaver** - Minimal screensaver with 30s clock position shifting to prevent burn-in.
- **Easy WiFi Access** - Network indicator doubles as a shortcut to system WiFi settings.
- **Quick Presets** - Select Time/Date formats and Category names from a list (no keyboard required).
- **Video Wallpaper** - Set animated video files as your home screen background.
- **Dynamic & Time-Based Wallpaper** - Switch between day/night backgrounds or enable automatic dark mode based on time.
- **Watch Next Section** - Continue watching your shows with a dedicated "Watch Next" row at the top.
- **Pitch Black Wallpaper** - A true black gradient background option for OLED optimization.
- **Enhanced Focus Indicator** - New double-border design ensures perfect visibility on any background.
- **Smart Navigation** - Fixed "bounce back" issues and optimized focus traversal.
- **Refined Settings** - Reorganized menus with a new "Miscellaneous" section and unified focus styles.
- **Accent Color Support** - Personalize the UI with multiple color presets.
- **Improved Sorting** - Reorder categories using Left/Right arrow keys.
- **Left Side Settings** - Settings panel opens on the left for better reach.
- **Brightness Scheduler (Experimental)** - Adjust system brightness by time of day (requires `WRITE_SETTINGS` via ADB).
- **Custom Banner Support** - Display and apply your own personalized custom banners.
- **Compatibility** - Works on Android TV boxes, Fire TV Stick, and other devices.

Added by this fork:

- **Media controls** in the status bar for any media session.
- **Dock magnification** (macOS-style, focus-distance scaling) with a sliding focus highlight.
- **Status bar gradient scrim** (off / small / medium / large) for readable icons over bright wallpapers.
- **Clock size & font style**, with the date matching the clock.
- **Slideshow shuffle / sequential** ordering.
- **Open-app animation** (zoom / page flip / pulse / circle) with a selectable start delay.
- **Blur during slideshow** and a blur-over-video toggle.

> [!TIP]
> **Video Wallpaper Performance:** keep video files small (ideally under 10 MB,
> 1080p or lower). The blur-over-video toggle is off by default for the same
> reason — enabling it re-blurs the dock region every frame.

## Set Arc Launcher as default launcher

### Set the home activity over ADB (recommended)

A single command, it leaves the stock launcher untouched, and it can be undone
just as easily:

```shell
$ adb shell cmd package set-home-activity com.omeda.arc/.MainActivity
```

To check which launcher is currently set as home:

```shell
$ adb shell cmd package resolve-activity -c android.intent.category.HOME -a android.intent.action.MAIN
```

To go back to the stock launcher:

```shell
$ adb shell cmd package query-activities -c android.intent.category.HOME -a android.intent.action.MAIN
$ adb shell cmd package set-home-activity <package>/<activity>
```

> **Note**
> `set-home-activity` requires Android 8.1 or newer, and what it accepts differs
> by version. On Android 10 and above it assigns the `HOME` role through
> `RoleManager` and the package name alone is enough. On Android 8.1 to 9 it
> sets a preferred activity directly and needs the full `<package>/<activity>`
> form.

### Fallback: disable the stock launcher

Some firmwares (including the TCL this fork targets) hard-force Home back to
the stock launcher. On those boxes the home-activity preference alone may not
stick, and disabling the stock launcher is the working fallback:

```shell
$ adb shell pm disable-user --user 0 com.google.android.tvlauncher
```

Re-enable it with:

```shell
$ adb shell pm enable com.google.android.tvlauncher
```

> **:warning: Disclaimer :warning:**
> You are doing this at your own risk. The package name above is the Google TV
> launcher's; on your device it may differ — list the launchers with the
> `query-activities` command above and use the right one.

## TCL Google TV notes

On the TCL box this fork was developed for, two quirks are worth knowing:

- **Media controls need a one-time grant, repeated after every app update**
  (Android wipes the notification-listener setting when the package is
  updated):

  ```shell
  $ adb shell appops set com.omeda.arc APP_AUTO_START allow
  $ adb shell cmd notification allow_listener com.omeda.arc/.MediaSessionListenerService 0
  ```

  The first line is required because the firmware's app-boot manager refuses to
  bind services for apps without the auto-start app op. There is no notification
  access screen in the TV settings UI, so `adb` (or the "Grant media access" row
  in Settings → Interface → Status bar, which opens the app details page) is the
  way to do it.

- **Disabling the stock launcher** (see the fallback above) is what makes the
  Home key open Arc on this firmware.

## Wallpaper

Because Android's `WallpaperManager` is not available on some Android TV
devices, Arc Launcher implements its own wallpaper management method. Changing
wallpaper requires a file explorer to be installed on the device in order to
pick a file.

## Credits and contributors

<a href="https://github.com/jiramet2k21/arclauncher/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=jiramet2k21/arclauncher" alt="Contributors" />
</a>

### Original Projects

- **[FLauncher](https://gitlab.com/flauncher/flauncher)** by [etienn01](https://github.com/etienn01) - The original project
- **[FLauncher (Fork)](https://github.com/osrosal/flauncher)** by [osrosal](https://github.com/osrosal) - Community fork with additional features
- **[LTvLauncher](https://github.com/LeanBitLab/LtvLauncher)** by [LeanBitLab](https://github.com/LeanBitLab) - The base for this fork
- **[Arc Launcher](https://github.com/meddouribadis/arclauncher)** by [meddouribadis](https://github.com/meddouribadis) - The fork this is based on
