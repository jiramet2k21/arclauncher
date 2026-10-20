import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class SlideshowModePage extends StatelessWidget {
  static const String routeName = "slideshow_mode_panel";

  const SlideshowModePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
      builder: (context, service, _) {
        return Column(
          children: [
            Text(localizations.slideshowMode, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _radioTile(context, service, localizations.slideshowModeShuffle, true),
                  _radioTile(context, service, localizations.slideshowModeSequential, false),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _radioTile(BuildContext context, SettingsService service, String label, bool value) {
    final isSelected = service.slideshowShuffle == value;
    return FocusableSettingsTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      onPressed: () => service.setSlideshowShuffle(value),
    );
  }
}
