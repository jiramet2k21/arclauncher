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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'settings_service.dart';

/// Current conditions for today (status bar + hero of the popup).
class CurrentWeather {
  final double temperature;
  final int weatherCode;
  final double apparentTemperature;
  final int humidity;
  final double windSpeed;
  final double windGust;
  final int windDirection;
  final double pressure;
  final double dewPoint;

  /// Today's high/low, taken from the first entry of the daily block.
  final double high;
  final double low;

  const CurrentWeather({
    required this.temperature,
    required this.weatherCode,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.windGust,
    required this.windDirection,
    required this.pressure,
    required this.dewPoint,
    required this.high,
    required this.low,
  });
}

/// One day of the 7-day forecast.
class DailyWeather {
  final DateTime date;
  final int weatherCode;
  final double high;
  final double low;

  const DailyWeather({
    required this.date,
    required this.weatherCode,
    required this.high,
    required this.low,
  });
}

/// One entry of the 24-hour chart (temperature + precipitation probability).
class HourlyPoint {
  final double temperature;
  final int precipProbability;

  const HourlyPoint({required this.temperature, required this.precipProbability});
}

/// Air quality + UV from Open-Meteo's air-quality endpoint (optional).
class AirQuality {
  final int? usAqi;
  final double? uvIndex;

  const AirQuality({required this.usAqi, required this.uvIndex});
}

/// Current conditions + 7-day forecast + 24h chart for the configured location.
class WeatherData {
  final CurrentWeather current;
  final List<DailyWeather> daily;
  final List<HourlyPoint> hourly;

  /// Surface pressure change over the last ~2 hours (hPa). Positive = rising.
  final double pressureTrend;

  /// Visibility in kilometers (from the current hour).
  final double visibilityKm;

  /// Air quality / UV; null when the endpoint failed or returned nothing.
  final AirQuality? air;

  const WeatherData({
    required this.current,
    required this.daily,
    required this.hourly,
    required this.pressureTrend,
    required this.visibilityKm,
    required this.air,
  });
}

/// Fetches weather data from Open-Meteo (free, no API key).
class WeatherService extends ChangeNotifier {
  final SettingsService _settings;

  /// Last successful fetch, displayed until replaced. Never cleared on error
  /// so the status bar keeps showing the last good values.
  WeatherData? data;

  /// True while a fetch is in flight.
  bool loading = false;

  /// Human-readable reason when the last fetch failed (data may still exist).
  String? error;

  DateTime? _lastFetch;
  Timer? _timer;

  // Mirrors of the location settings so we only refetch when the weather
  // configuration itself changes, not on unrelated settings updates.
  bool _lastEnabled = false;
  String _lastCity = "";
  double _lastLatitude = 0.0;
  double _lastLongitude = 0.0;

  WeatherService(this._settings) {
    _lastEnabled = _settings.weatherEnabled;
    _lastCity = _settings.weatherCityName;
    _lastLatitude = _settings.weatherLatitude;
    _lastLongitude = _settings.weatherLongitude;
    _settings.addListener(_onSettingsChanged);
    if (_settings.weatherEnabled && _hasLocation) {
      refresh();
    }
  }

  bool get _hasLocation => _settings.weatherCityName.isNotEmpty;

  /// Fetches immediately when there is no data yet or the data is older than
  /// 15 minutes. Used when the user opens the weather popup.
  Future<void> refreshIfStale() async {
    if (data == null ||
        DateTime.now().difference(_lastFetch!) > const Duration(minutes: 15)) {
      await refresh();
    }
  }

  /// Fetches current conditions + the 7-day forecast and schedules the next
  /// refresh in one hour.
  Future<void> refresh() async {
    if (!_settings.weatherEnabled || !_hasLocation || loading) {
      return;
    }

    loading = true;
    notifyListeners();
    try {
      final response = await http
          .get(Uri.https("api.open-meteo.com", "/v1/forecast", {
            "latitude": "${_settings.weatherLatitude}",
            "longitude": "${_settings.weatherLongitude}",
            "current":
                "temperature_2m,weather_code,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_gusts_10m,wind_direction_10m,surface_pressure,dew_point_2m",
            "hourly": "temperature_2m,precipitation_probability,visibility,surface_pressure",
            "forecast_hours": "24",
            "past_hours": "2",
            "daily": "weather_code,temperature_2m_max,temperature_2m_min",
            "forecast_days": "8",
            "timezone": "auto",
          }))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception("Weather HTTP ${response.statusCode}");
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      data = _parseForecast(body, air: await _loadAirQuality());
      error = null;
      _lastFetch = DateTime.now();
    } catch (exception, stackTrace) {
      // Keep the last good data; remember the failure for the popup.
      error = "$exception";
      debugPrint("WeatherService: fetch failed $exception\n$stackTrace");
    }
    loading = false;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 60), refresh);
  }

  WeatherData _parseForecast(
    Map<String, dynamic> body, {
    required AirQuality? air,
  }) {
    final current = body["current"] as Map<String, dynamic>;
    final daily = body["daily"] as Map<String, dynamic>;
    final hourly = body["hourly"] as Map<String, dynamic>? ?? {};

    final dates =
        (daily["time"] as List? ?? []).map((value) => value.toString()).toList();
    final highs = _toDoubleList(daily["temperature_2m_max"]);
    final lows = _toDoubleList(daily["temperature_2m_min"]);
    final codes = _toIntList(daily["weather_code"]);

    final forecast = <DailyWeather>[];
    for (var i = 0; i < 7; i++) {
      if (i >= dates.length || i >= highs.length || i >= lows.length || i >= codes.length) {
        break;
      }
      forecast.add(DailyWeather(
        date: DateTime.parse(dates[i]),
        weatherCode: codes[i],
        high: highs[i],
        low: lows[i],
      ));
    }

    // Hourly block: past_hours=2 puts the current hour at index 2
    // (indexes 0-1 are in the past). Chart uses indexes 2..25.
    final hourlyTemps = _toDoubleList(hourly["temperature_2m"]);
    final hourlyPops = _toIntList(hourly["precipitation_probability"]);
    final hourlyPressure = _toDoubleList(hourly["surface_pressure"]);
    final hourlyVisibility = _toDoubleList(hourly["visibility"]);

    final chart = <HourlyPoint>[];
    for (var i = 2; i < 2 + 24; i++) {
      if (i >= hourlyTemps.length) {
        break;
      }
      chart.add(HourlyPoint(
        temperature: hourlyTemps[i],
        precipProbability: i < hourlyPops.length ? hourlyPops[i] : 0,
      ));
    }

    double visibilityKm = 0.0;
    if (hourlyVisibility.isNotEmpty && hourlyVisibility.length > 2) {
      visibilityKm = hourlyVisibility[2] / 1000.0;
    }

    double pressureTrend = 0.0;
    if (hourlyPressure.length > 2) {
      pressureTrend = hourlyPressure[2] - hourlyPressure[0];
    }

    return WeatherData(
      current: CurrentWeather(
        temperature: _toDouble(current["temperature_2m"]) ?? 0.0,
        weatherCode: _toInt(current["weather_code"]) ?? 0,
        apparentTemperature: _toDouble(current["apparent_temperature"]) ?? 0.0,
        humidity: _toInt(current["relative_humidity_2m"]) ?? 0,
        windSpeed: _toDouble(current["wind_speed_10m"]) ?? 0.0,
        windGust: _toDouble(current["wind_gusts_10m"]) ?? 0.0,
        windDirection: _toInt(current["wind_direction_10m"]) ?? 0,
        pressure: _toDouble(current["surface_pressure"]) ?? 0.0,
        dewPoint: _toDouble(current["dew_point_2m"]) ?? 0.0,
        high: forecast.isNotEmpty ? forecast.first.high : 0.0,
        low: forecast.isNotEmpty ? forecast.first.low : 0.0,
      ),
      daily: forecast,
      hourly: chart,
      pressureTrend: pressureTrend,
      visibilityKm: visibilityKm,
      air: air,
    );
  }

  /// Fetches US AQI + UV index from Open-Meteo's air-quality API. Failures
  /// return null so forecast data still renders (tiles show "–").
  Future<AirQuality?> _loadAirQuality() async {
    try {
      final response = await http
          .get(Uri.https("air-quality-api.open-meteo.com", "/v1/air-quality", {
            "latitude": "${_settings.weatherLatitude}",
            "longitude": "${_settings.weatherLongitude}",
            "current": "us_aqi,uv_index",
          }))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint("WeatherService: air-quality HTTP ${response.statusCode}");
        return null;
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final current = body["current"] as Map<String, dynamic>? ?? {};
      return AirQuality(
        usAqi: _toInt(current["us_aqi"]),
        uvIndex: _toDouble(current["uv_index"]),
      );
    } catch (exception, stackTrace) {
      debugPrint("WeatherService: air-quality fetch failed $exception\n$stackTrace");
      return null;
    }
  }

  /// Maps a WMO weather code to a Material icon.
  IconData weatherIconFor(int code) {
    if (code == 0) {
      return Icons.wb_sunny_outlined;
    }
    if (code == 1) {
      return Icons.wb_sunny;
    }
    if (code <= 3) {
      return Icons.wb_cloudy;
    }
    if (code <= 48) {
      return Icons.blur_on; // fog
    }
    if (code <= 57) {
      return Icons.grain; // drizzle
    }
    if (code <= 67) {
      return Icons.water_drop; // rain / freezing rain
    }
    if (code <= 77) {
      return Icons.ac_unit; // snow
    }
    if (code <= 82) {
      return Icons.water_drop; // showers
    }
    if (code <= 86) {
      return Icons.ac_unit; // snow showers
    }
    return Icons.thunderstorm;
  }

  /// Maps a WMO weather code to a short description.
  String weatherDescriptionFor(int code) {
    switch (code) {
      case 0:
        return "Clear sky";
      case 1:
        return "Mainly clear";
      case 2:
        return "Partly cloudy";
      case 3:
        return "Overcast";
      case 45:
      case 48:
        return "Fog";
      case 51:
        return "Light drizzle";
      case 53:
        return "Drizzle";
      case 55:
        return "Heavy drizzle";
      case 56:
      case 57:
        return "Freezing drizzle";
      case 61:
        return "Light rain";
      case 63:
        return "Rain";
      case 65:
        return "Heavy rain";
      case 66:
      case 67:
        return "Freezing rain";
      case 71:
        return "Light snow";
      case 73:
        return "Snow";
      case 75:
        return "Heavy snow";
      case 77:
        return "Snow grains";
      case 80:
      case 81:
      case 82:
        return "Showers";
      case 85:
      case 86:
        return "Snow showers";
      case 95:
        return "Thunderstorm";
      default:
        return "Thunderstorm";
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    final enabledChanged = _lastEnabled != _settings.weatherEnabled;
    final locationChanged = _lastCity != _settings.weatherCityName ||
        _lastLatitude != _settings.weatherLatitude ||
        _lastLongitude != _settings.weatherLongitude;

    _lastEnabled = _settings.weatherEnabled;
    _lastCity = _settings.weatherCityName;
    _lastLatitude = _settings.weatherLatitude;
    _lastLongitude = _settings.weatherLongitude;

    if (locationChanged || (enabledChanged && _settings.weatherEnabled)) {
      // New configuration — drop the old data so nothing stale lingers.
      data = null;
      _lastFetch = null;
      refresh();
    }
  }

  double? _toDouble(dynamic value) => value is num ? value.toDouble() : null;

  int? _toInt(dynamic value) => value is num ? value.toInt() : null;

  List<double> _toDoubleList(dynamic values) =>
      (values as List? ?? []).map((value) => (value is num) ? value.toDouble() : 0.0).toList();

  List<int> _toIntList(dynamic values) =>
      (values as List? ?? []).map((value) => (value is num) ? value.toInt() : 0).toList();
}
