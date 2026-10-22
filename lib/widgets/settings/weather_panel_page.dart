/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/weather_location_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_service.dart';
import '../../providers/weather_service.dart';

class WeatherPanelPage extends StatelessWidget {
  static const String routeName = "weather_panel";

  const WeatherPanelPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Weather", style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Consumer<SettingsService>(
                builder: (context, settings, __) => RoundedSwitchListTile(
                  autofocus: true,
                  value: settings.weatherEnabled,
                  onChanged: (value) => settings.setWeatherEnabled(value),
                  title: const Text("Enabled"),
                  secondary: const Icon(Icons.thermostat),
                ),
              ),
              const Divider(),
              Consumer<SettingsService>(
                builder: (context, settings, __) => FocusableSettingsTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text("Weather location"),
                  trailing: Text(
                    settings.weatherCityName.isEmpty ? "Not set" : settings.weatherCityName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => Navigator.of(context).pushNamed(WeatherLocationPage.routeName),
                ),
              ),
              Consumer<WeatherService>(
                builder: (context, weather, __) => FocusableSettingsTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text("Refresh now"),
                  trailing: weather.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const SizedBox.shrink(),
                  onPressed: () => weather.refreshIfStale(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
