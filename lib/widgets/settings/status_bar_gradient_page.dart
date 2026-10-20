import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class StatusBarGradientPage extends StatelessWidget {
  static const String routeName = "status_bar_gradient_panel";

  const StatusBarGradientPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
      builder: (context, service, _) {
        return Column(
          children: [
            Text(localizations.statusBarGradient, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView(
                children: statusBarGradientOptions
                    .map((value) => _radioTile(context, service, value))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _radioTile(BuildContext context, SettingsService service, String value) {
    final isSelected = service.statusBarGradient == value;
    String label;
    switch (value) {
      case "small":
        label = "Small";
        break;
      case "medium":
        label = "Medium";
        break;
      case "large":
        label = "Large";
        break;
      case "off":
      default:
        label = "Off";
        break;
    }
    return FocusableSettingsTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      onPressed: () => service.setStatusBarGradient(value),
    );
  }
}
