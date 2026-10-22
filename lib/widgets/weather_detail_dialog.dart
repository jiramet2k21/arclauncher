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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/weather_service.dart';

/// Weather popup: header (city + close), today's extended conditions,
/// then a "7-Day Forecast" list (icon | weekday | low | high).
class WeatherDetailDialog extends StatelessWidget {
  final String cityName;

  const WeatherDetailDialog({Key? key, required this.cityName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherService>(
      builder: (context, weather, _) {
        final data = weather.data;

        return Dialog(
          child: Container(
            width: 560,
            height: 520,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: city name + close button (BACK also closes).
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cityName,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: "Close",
                    ),
                  ],
                ),
                const Divider(),

                Expanded(child: _body(context, weather, data)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, WeatherService weather, WeatherData? data) {
    final textTheme = Theme.of(context).textTheme;

    if (weather.loading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data == null) {
      return Center(
        child: Text(
          "Weather unavailable.\nSet a location in Settings > Status bar > Weather.",
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
      );
    }

    final current = data.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Today's extended conditions.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              weather.weatherIconFor(current.weatherCode),
              size: 56,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${current.temperature.round()}°",
                  style: textTheme.headlineMedium,
                ),
                Text(
                  weather.weatherDescriptionFor(current.weatherCode),
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailLine(context, Icons.device_thermostat, "Feels like ${current.apparentTemperature.round()}°"),
                  _detailLine(context, Icons.water_drop, "Humidity ${current.humidity}%"),
                  _detailLine(context, Icons.air, "Wind ${current.windSpeed.round()} km/h"),
                  _detailLine(context, Icons.swap_vert, "High ${current.high.round()}°   Low ${current.low.round()}°"),
                ],
              ),
            ),
          ],
        ),
        if (weather.error != null) ...[
          const SizedBox(height: 12),
          Text(
            "Update failed — showing last known weather.",
            style: textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        Text("7-DAY FORECAST", style: textTheme.labelLarge?.copyWith(color: Colors.white70)),
        // Weekly rows: icon | weekday | low | high. Plain rows (not focusable).
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 4),
            children: [for (var day in data.daily) _dailyRow(context, weather, day)],
          ),
        ),
      ],
    );
  }

  Widget _detailLine(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _dailyRow(BuildContext context, WeatherService weather, DailyWeather day) {
    final textTheme = Theme.of(context).textTheme;
    final leading = day.date.day == DateTime.now().day ? "Today" : DateFormat("EEE d").format(day.date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(weather.weatherIconFor(day.weatherCode), color: Colors.white70),
          const SizedBox(width: 16),
          Text(leading, style: textTheme.bodyMedium),
          const Spacer(),
          Text(
            "${day.low.round()}°",
            style: textTheme.bodyMedium?.copyWith(color: Colors.white54),
          ),
          const SizedBox(width: 24),
          Text("${day.high.round()}°", style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
