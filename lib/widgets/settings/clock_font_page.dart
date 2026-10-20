import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/clock_text_style.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ClockFontPage extends StatelessWidget {
  static const String routeName = "clock_font_panel";

  const ClockFontPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Consumer<SettingsService>(
      builder: (context, service, _) {
        return Column(
          children: [
            Text(localizations.clockFont, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView(
                children: clockFontStyleOptions
                    .map((style) => _radioTile(context, service, localizations, style))
                    .toList(),
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
    AppLocalizations localizations,
    String style,
  ) {
    final isSelected = service.clockFontStyle == style;
    return FocusableSettingsTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      // The label is rendered in the style it represents.
      title: Text(
        clockFontStyleLabel(localizations, style),
        style: clockTextStyle(context, 24, style),
      ),
      onPressed: () => service.setClockFontStyle(style),
    );
  }
}
