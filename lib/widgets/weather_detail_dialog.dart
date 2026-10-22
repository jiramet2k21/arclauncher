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

/// iOS-style weather popup: condition-tinted gradient panel with a large
/// hero block (city/temperature/condition) on the left and two glass cards
/// (current conditions + one-line 7-day forecast with gradient range bars)
/// on the right. BACK also closes.
class WeatherDetailDialog extends StatelessWidget {
  final String cityName;

  const WeatherDetailDialog({Key? key, required this.cityName}) : super(key: key);

  static const Color _cardColor = Color(0x26FFFFFF); // white ~15%

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherService>(
      builder: (context, weather, _) {
        final data = weather.data;
        final int? code = data?.current.weatherCode;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
          child: Container(
            width: 760,
            height: 480,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: _backgroundGradient(code),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 32, offset: Offset(0, 12)),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
                    child: _content(context, weather, data),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _closeButton(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, WeatherService weather, WeatherData? data) {
    if (weather.loading && data == null) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 3),
        ),
      );
    }
    if (data == null) {
      return Center(
        child: Text(
          "Weather unavailable.\nSet a location in Settings > Interface > Status bar > Weather.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8)),
        ),
      );
    }

    final current = data.current;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero: city, large temperature, condition, high/low.
        SizedBox(
          width: 250,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "${current.temperature.round()}°",
                style: const TextStyle(
                  fontSize: 88,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -3,
                  height: 1.05,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                weather.weatherDescriptionFor(current.weatherCode),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "H:${current.high.round()}°  L:${current.low.round()}°",
                style: const TextStyle(fontSize: 15, color: Colors.white70),
              ),
              if (weather.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  "Update failed — showing last known weather.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 28),
        // Right column: current details + 7-day forecast.
        Expanded(
          child: Column(
            children: [
              _currentCard(context, weather, current),
              const SizedBox(height: 14),
              Expanded(child: _forecastCard(context, weather, data)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _currentCard(BuildContext context, WeatherService weather, CurrentWeather current) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardCaption("CURRENT"),
          const SizedBox(height: 6),
          _detailLine(
            Icons.device_thermostat,
            Colors.orangeAccent,
            "Feels like ${current.apparentTemperature.round()}°",
          ),
          _detailLine(Icons.water_drop, Colors.lightBlueAccent, "Humidity ${current.humidity}%"),
          _detailLine(Icons.air, Colors.tealAccent, "Wind ${current.windSpeed.round()} km/h"),
          _detailLine(
            Icons.swap_vert,
            Colors.purpleAccent,
            "High ${current.high.round()}°   Low ${current.low.round()}°",
          ),
        ],
      ),
    );
  }

  Widget _forecastCard(BuildContext context, WeatherService weather, WeatherData data) {
    double weekMin = double.infinity;
    double weekMax = double.negativeInfinity;
    for (final day in data.daily) {
      if (day.low < weekMin) {
        weekMin = day.low;
      }
      if (day.high > weekMax) {
        weekMax = day.high;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardCaption("7-DAY FORECAST"),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 2),
              children: [
                for (var i = 0; i < data.daily.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 0.5, color: Colors.white.withValues(alpha: 0.12)),
                  _dailyRow(context, weather, data.daily[i], weekMin, weekMax),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardCaption(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: Colors.white70,
      ),
    );
  }

  Widget _detailLine(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _dailyRow(
    BuildContext context,
    WeatherService weather,
    DailyWeather day,
    double weekMin,
    double weekMax,
  ) {
    final label = day.date.day == DateTime.now().day ? "Today" : DateFormat("EEE d").format(day.date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: label == "Today" ? FontWeight.w700 : FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(weather.weatherIconFor(day.weatherCode), size: 20, color: _iconColorFor(day.weatherCode)),
          const SizedBox(width: 12),
          SizedBox(
            width: 34,
            child: Text(
              "${day.low.round()}°",
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _rangeBar(day.low, day.high, weekMin, weekMax)),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              "${day.high.round()}°",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS-style temperature range bar: faint track with a teal -> yellow ->
  /// orange fill positioned between the day's low and high within the
  /// week's overall range.
  Widget _rangeBar(double low, double high, double weekMin, double weekMax) {
    final range = (weekMax - weekMin).clamp(1.0, double.infinity);
    final span = (high - low).clamp(0.0, double.infinity);
    final startFraction = ((low - weekMin) / range).clamp(0.0, 1.0);
    final widthFraction = (span / range).clamp(0.08, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final barWidth = (widthFraction * width).clamp(10.0, width);
        return SizedBox(
          height: 5,
          child: Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: startFraction * width,
                child: Container(
                  height: 5,
                  width: barWidth,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF61D4C0), Color(0xFFFFD54F), Color(0xFFFF8A65)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Condition-colored forecast icons so each row reads at a glance.
  Color _iconColorFor(int code) {
    if (code <= 1) {
      return const Color(0xFFFFC94D); // clear — warm amber
    }
    if (code <= 3) {
      return Colors.white70; // clouds
    }
    if (code == 45 || code == 48) {
      return const Color(0xFFB0BEC5); // fog — blue grey
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return const Color(0xFF7EC8FF); // rain/drizzle — light blue
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return Colors.white; // snow
    }
    if (code >= 95) {
      return const Color(0xFFFF7043); // thunderstorm
    }
    return Colors.white70;
  }

  /// Condition-tinted background gradient (top -> bottom) by WMO code.
  LinearGradient _backgroundGradient(int? code) {
    if (code == null) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3D7ECC), Color(0xFF16294E)],
      );
    }
    List<Color> colors;
    if (code <= 1) {
      colors = const [Color(0xFF3D7ECC), Color(0xFF16294E)]; // clear
    } else if (code == 2) {
      colors = const [Color(0xFF54749E), Color(0xFF22344F)]; // partly cloudy
    } else if (code == 3 || code == 45 || code == 48) {
      colors = const [Color(0xFF5D6B7A), Color(0xFF2A343E)]; // overcast / fog
    } else if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      colors = const [Color(0xFF46617F), Color(0xFF1D2B3C)]; // rain / showers
    } else if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      colors = const [Color(0xFF7A93AD), Color(0xFF34455A)]; // snow
    } else {
      colors = const [Color(0xFF232F46), Color(0xFF0B1120)]; // thunderstorm
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );
  }

  Widget _closeButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
