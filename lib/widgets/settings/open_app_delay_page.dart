import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class OpenAppDelayPage extends StatelessWidget {
  static const String routeName = "open_app_delay_panel";

  const OpenAppDelayPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
      builder: (context, service, _) {
        return Column(
          children: [
            Text(localizations.appOpenDelay, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView(
                children: openAppLaunchDelayOptions
                    .map((seconds) => _radioTile(context, service, seconds))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _radioTile(BuildContext context, SettingsService service, int seconds) {
    final isSelected = service.openAppLaunchDelay == seconds;
    return FocusableSettingsTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Text("$seconds s", style: Theme.of(context).textTheme.bodyMedium),
      onPressed: () => service.setOpenAppLaunchDelay(seconds),
    );
  }
}
