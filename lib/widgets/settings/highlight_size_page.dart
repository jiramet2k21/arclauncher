import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class HighlightSizePage extends StatelessWidget {
  static const String routeName = "highlight_size_panel";

  const HighlightSizePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
      builder: (context, service, _) {
        return Column(
          children: [
            Text(localizations.appHighlightSize, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView(
                children: appHighlightSizeOptions
                    .map((size) => _radioTile(context, service, size))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _radioTile(BuildContext context, SettingsService service, String size) {
    final isSelected = service.appHighlightSize == size;
    String label;
    switch (size) {
      case "medium":
        label = "Medium";
        break;
      case "large":
        label = "Large";
        break;
      case "small":
      default:
        label = "Small";
        break;
    }
    return FocusableSettingsTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      onPressed: () => service.setAppHighlightSize(size),
    );
  }
}
