import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class ClockSizePage extends StatelessWidget {
  static const String routeName = "clock_size_panel";

  const ClockSizePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
      builder: (context, service, _) {
        return Column(
          children: [
            Text(localizations.clockSize, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView(
                children: clockSizeOptions.map((size) => _radioTile(context, service, size)).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _radioTile(BuildContext context, SettingsService service, int size) {
    final isSelected = service.clockSize == size;
    String label;
    switch (size) {
      case 28:
        label = "Small";
        break;
      case 56:
        label = "Large";
        break;
      case 72:
        label = "Extra large";
        break;
      case 40:
      default:
        label = "Normal";
        break;
    }
    return FocusableSettingsTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Text("$label ($size)", style: Theme.of(context).textTheme.bodyMedium),
      onPressed: () => service.setClockSize(size),
    );
  }
}
