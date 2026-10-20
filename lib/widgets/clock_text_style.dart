import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Builds the status-bar clock/date text style from the size + font style
/// settings. The date renders with the exact same style (same size, same
/// typeface) — only the clock stays bold by default.
TextStyle clockTextStyle(
  BuildContext context,
  int size,
  String fontStyle, {
  bool bold = false,
}) {
  final accent = Theme.of(context).colorScheme.secondary;
  final base = TextStyle(
    fontSize: size.toDouble(),
    fontWeight: bold ? FontWeight.bold : FontWeight.w400,
    color: Colors.white,
    shadows: const [
      Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)
    ],
  );

  switch (fontStyle) {
    case "bold":
      return base.copyWith(fontWeight: FontWeight.w700);
    case "monospace":
      return base.copyWith(fontFamily: "monospace");
    case "serif":
      return base.copyWith(fontFamily: "serif");
    case "condensed":
      return base.copyWith(fontFamily: "sans-serif-condensed");
    case "glow":
      return base.copyWith(shadows: [
        Shadow(color: accent, blurRadius: 12),
        Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 28),
        const Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 6),
      ]);
    case "default":
    default:
      return base;
  }
}

/// Human-readable label for a clock font style key.
String clockFontStyleLabel(AppLocalizations localizations, String style) {
  switch (style) {
    case "bold":
      return localizations.fontStyleBold;
    case "monospace":
      return localizations.fontStyleMonospace;
    case "serif":
      return localizations.fontStyleSerif;
    case "condensed":
      return localizations.fontStyleCondensed;
    case "glow":
      return localizations.fontStyleGlow;
    case "default":
    default:
      return localizations.fontStyleDefault;
  }
}
