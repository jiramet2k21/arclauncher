import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Human-readable label for an "open app" animation style key.
String openAppAnimationStyleLabel(AppLocalizations localizations, String style) {
  switch (style) {
    case "flip":
      return localizations.animStyleFlip;
    case "pulse":
      return localizations.animStylePulse;
    case "circle":
      return localizations.animStyleCircle;
    case "zoom":
    default:
      return localizations.animStyleZoom;
  }
}

class OpenAppAnimationPage extends StatelessWidget {
  static const String routeName = "open_app_animation_panel";

  const OpenAppAnimationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
      builder: (context, service, _) {
        return Column(
          children: [
            Text(localizations.openAppAnimationStyle, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _radioTile(context, service, localizations.animStyleZoom, "zoom", Icons.open_in_full),
                  _radioTile(context, service, localizations.animStyleFlip, "flip", Icons.flip),
                  _radioTile(context, service, localizations.animStylePulse, "pulse", Icons.favorite_border),
                  _radioTile(context, service, localizations.animStyleCircle, "circle", Icons.circle_outlined),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _radioTile(
    BuildContext context,
    SettingsService service,
    String label,
    String style,
    IconData icon,
  ) {
    final isSelected = service.openAppAnimationStyle == style;
    return FocusableSettingsTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      onPressed: () => service.setOpenAppAnimationStyle(style),
    );
  }
}
