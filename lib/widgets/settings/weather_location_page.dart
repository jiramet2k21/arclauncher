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

import 'dart:convert';

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

/// City search backed by the Open-Meteo geocoding API. Opening the text field
/// shows the TV/soft keyboard; selecting a result saves the location and
/// returns to the weather panel.
class WeatherLocationPage extends StatefulWidget {
  static const String routeName = "weather_location";

  const WeatherLocationPage({Key? key}) : super(key: key);

  @override
  State<WeatherLocationPage> createState() => _WeatherLocationPageState();
}

class _GeocodeResult {
  final String name;
  final String? admin1;
  final String country;
  final double latitude;
  final double longitude;

  const _GeocodeResult({
    required this.name,
    required this.admin1,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  String get label => admin1 == null || admin1!.isEmpty
      ? "$name ($country)"
      : "$name, $admin1 ($country)";
}

class _WeatherLocationPageState extends State<WeatherLocationPage> {
  final TextEditingController _controller = TextEditingController();
  List<_GeocodeResult> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _searching) {
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final response = await http
          .get(Uri.https("geocoding-api.open-meteo.com", "/v1/search", {
            "name": query,
            "count": "5",
          }))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception("HTTP ${response.statusCode}");
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final rawResults = body["results"] as List? ?? [];
      final parsed = rawResults
          .whereType<Map<String, dynamic>>()
          .where((result) =>
              result["name"] != null &&
              result["latitude"] is num &&
              result["longitude"] is num)
          .map((result) => _GeocodeResult(
                name: result["name"].toString(),
                admin1: result["admin1"]?.toString(),
                country: result["country"]?.toString() ?? "",
                latitude: (result["latitude"] as num).toDouble(),
                longitude: (result["longitude"] as num).toDouble(),
              ))
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _results = parsed;
        if (parsed.isEmpty) {
          _error = "No places found.";
        }
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = "Search failed: $exception";
      });
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _searching = false;
    });
  }

  Future<void> _select(_GeocodeResult result) async {
    await context.read<SettingsService>().setWeatherLocation(
          result.name,
          result.latitude,
          result.longitude,
        );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Weather location", style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Text(
                "Search for a city, then select it from the results below.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  labelText: "City",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                autofocus: false,
                icon: const Icon(Icons.search),
                label: const Text("Search"),
                onPressed: _searching ? null : _search,
              ),
              if (_searching) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              for (final result in _results)
                FocusableSettingsTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(result.label),
                  onPressed: () => _select(result),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
