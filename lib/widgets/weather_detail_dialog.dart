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

import 'dart:math' as math;
import 'dart:ui' show TextDirection;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/weather_service.dart';

/// Reference-style light weather popup: a white main panel (hero, 7-day
/// strip, 24h temperature/precipitation chart) plus a 2x3 grid of info
/// tiles (Visibility, Pressure, AQI, Wind, Humidity, UV). BACK closes.
class WeatherDetailDialog extends StatelessWidget {
  final String cityName;

  const WeatherDetailDialog({Key? key, required this.cityName}) : super(key: key);

  static const Color _titleColor = Color(0xFF475569);
  static const Color _valueColor = Color(0xFF0F172A);
  static const Color _subColor = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherService>(
      builder: (context, weather, _) {
        final data = weather.data;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
          child: Container(
            width: 840,
            height: 480,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF2FB), Color(0xFFD6E4F2)],
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 32, offset: Offset(0, 12)),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _content(context, weather, data),
                  ),
                ),
                Positioned(top: 10, right: 10, child: _closeButton(context)),
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
          width: 34,
          height: 34,
          child: CircularProgressIndicator(color: Color(0xFF60A5FA), strokeWidth: 3),
        ),
      );
    }
    if (data == null) {
      return Center(
        child: Text(
          "Weather unavailable.\nSet a location in Settings > Interface > Status bar > Weather.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: _titleColor),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main panel.
        Expanded(
          flex: 3,
          child: _panel(
            context,
            child: _mainPanel(context, weather, data),
          ),
        ),
        const SizedBox(width: 12),
        // Info tile grid.
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _visibilityTile(data)),
                    const SizedBox(width: 10),
                    Expanded(child: _pressureTile(data)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _aqiTile(data)),
                    const SizedBox(width: 10),
                    Expanded(child: _windTile(data)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _humidityTile(data)),
                    const SizedBox(width: 10),
                    Expanded(child: _uvTile(data)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------- main

  Widget _mainPanel(BuildContext context, WeatherService weather, WeatherData data) {
    final current = data.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cityName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: _valueColor,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(weather.weatherIconFor(current.weatherCode), size: 68, color: _accentFor(current.weatherCode)),
            const SizedBox(width: 12),
            Text(
              "${current.temperature.round()}°",
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
                color: _valueColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weather.weatherDescriptionFor(current.weatherCode),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _valueColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "H:${current.high.round()}°  L:${current.low.round()}°",
                    style: const TextStyle(fontSize: 13, color: _subColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 7-day strip: one slim column per day.
        Row(
          children: [
            for (var i = 0; i < data.daily.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _dailyColumn(weather, data.daily[i])),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Expanded(child: _hourlyChart(context, data)),
      ],
    );
  }

  Widget _dailyColumn(WeatherService weather, DailyWeather day) {
    final now = DateTime.now();
    final label = day.date.day == now.day ? "Today" : DateFormat("EEE d").format(day.date);

    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: label == "Today" ? FontWeight.w700 : FontWeight.w600,
            color: label == "Today" ? _valueColor : _titleColor,
          ),
        ),
        const SizedBox(height: 2),
        Icon(weather.weatherIconFor(day.weatherCode), size: 24, color: _accentFor(day.weatherCode)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "${day.high.round()}°",
                style: const TextStyle(fontWeight: FontWeight.w700, color: _valueColor),
              ),
              TextSpan(
                text: " ${day.low.round()}°",
                style: const TextStyle(color: _subColor),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _hourlyChart(BuildContext context, WeatherData data) {
    final points = data.hourly;
    if (points.length < 2) {
      return const SizedBox.shrink();
    }

    // Hour labels ("Now", then every hour) indexed together with points.
    final now = DateTime.now();
    final labels = <String>[
      for (var i = 0; i < points.length; i++)
        i == 0
            ? "Now"
            : DateFormat("h a").format(DateTime(now.year, now.month, now.day, now.hour + i)),
    ];

    return CustomPaint(
      size: Size.infinite,
      painter: _HourlyChartPainter(points: points, labels: labels),
    );
  }

  // ---------------------------------------------------------------- tiles

  Widget _tile({required String title, required Widget child, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _titleColor)),
          Expanded(child: child),
          if (subtitle != null)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _subColor),
            ),
        ],
      ),
    );
  }

  Widget _visibilityTile(WeatherData data) {
    final km = data.visibilityKm;
    String quality;
    if (km >= 20) {
      quality = "Excellent";
    } else if (km >= 10) {
      quality = "Good";
    } else if (km >= 4) {
      quality = "Moderate";
    } else if (km >= 1) {
      quality = "Poor";
    } else if (km > 0) {
      quality = "Very poor";
    } else {
      quality = "–";
    }
    return _tile(
      title: "Visibility",
      subtitle: quality,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: km > 0 ? "${km.round()}" : "–",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _valueColor),
              ),
              if (km > 0)
                TextSpan(
                  text: " km",
                  style: const TextStyle(fontSize: 13, color: _titleColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pressureTile(WeatherData data) {
    final trend = data.pressureTrend;
    IconData trendIcon;
    Color trendColor;
    if (trend >= 0.3) {
      trendIcon = Icons.arrow_drop_up;
      trendColor = const Color(0xFF0EA5E9);
    } else if (trend <= -0.3) {
      trendIcon = Icons.arrow_drop_down;
      trendColor = const Color(0xFFF59E0B);
    } else {
      trendIcon = Icons.remove;
      trendColor = const Color(0xFF94A3B8);
    }
    return _tile(
      title: "Pressure",
      subtitle: "hPa",
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            data.current.pressure.round().toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _valueColor),
          ),
          Icon(trendIcon, size: 30, color: trendColor),
        ],
      ),
    );
  }

  Widget _aqiTile(WeatherData data) {
    final air = data.air;
    final int? aqi = air?.usAqi;
    String category = "–";
    if (aqi != null) {
      if (aqi <= 50) {
        category = "Good";
      } else if (aqi <= 100) {
        category = "Moderate";
      } else if (aqi <= 150) {
        category = "Sensitive";
      } else if (aqi <= 200) {
        category = "Unhealthy";
      } else if (aqi <= 300) {
        category = "Very unhealthy";
      } else {
        category = "Hazardous";
      }
    }
    return _tile(
      title: "AQI",
      subtitle: category,
      child: Row(
        children: [
          Text(
            aqi?.toString() ?? "–",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _valueColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _GaugePainter(
                value: aqi?.toDouble(),
                min: 0,
                max: 300,
                colors: const [
                  Color(0xFF4CAF50),
                  Color(0xFFFFD54F),
                  Color(0xFFFF9800),
                  Color(0xFFF44336),
                  Color(0xFF9C27B0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _windTile(WeatherData data) {
    final current = data.current;
    return _tile(
      title: "Wind",
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CustomPaint(
              painter: _CompassPainter(direction: current.windDirection.toDouble()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${current.windSpeed.round()} km/h",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _valueColor),
                ),
                const SizedBox(height: 2),
                Text(
                  "Gust ${current.windGust.round()} km/h",
                  style: const TextStyle(fontSize: 11, color: _subColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _humidityTile(WeatherData data) {
    return _tile(
      title: "Humidity",
      subtitle: "Dew ${data.current.dewPoint.round()}°",
      child: Row(
        children: [
          const _HumidityBars(),
          const SizedBox(width: 10),
          Text(
            "${data.current.humidity}%",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }

  Widget _uvTile(WeatherData data) {
    final uv = data.air?.uvIndex;
    String category = "–";
    if (uv != null) {
      if (uv <= 2) {
        category = "Low";
      } else if (uv <= 5) {
        category = "Moderate";
      } else if (uv <= 7) {
        category = "High";
      } else if (uv <= 10) {
        category = "Very high";
      } else {
        category = "Extreme";
      }
    }
    return _tile(
      title: "UV",
      subtitle: category,
      child: Row(
        children: [
          Text(
            uv != null ? uv.round().toString() : "–",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _valueColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _GaugePainter(
                value: uv,
                min: 0,
                max: 11,
                colors: const [
                  Color(0xFF4CAF50),
                  Color(0xFFFFD54F),
                  Color(0xFFFF9800),
                  Color(0xFFF44336),
                  Color(0xFF9C27B0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- helpers

  Color _accentFor(int code) {
    if (code <= 1) {
      return const Color(0xFFF59E0B); // clear — amber
    }
    if (code <= 3) {
      return const Color(0xFF8A9BB0); // clouds
    }
    if (code == 45 || code == 48) {
      return const Color(0xFF90A4AE); // fog
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return const Color(0xFF38BDF8); // rain
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return const Color(0xFF60A5FA); // snow
    }
    if (code >= 95) {
      return const Color(0xFFF97316); // thunderstorm
    }
    return const Color(0xFF8A9BB0);
  }

  Widget _closeButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0x66FFFFFF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 18, color: Color(0xFF475569)),
        ),
      ),
    );
  }
}

/// 24h temperature fill chart with temp labels (above), droplet +
/// precipitation labels, and hour ticks every 3 hours.
class _HourlyChartPainter extends CustomPainter {
  final List<HourlyPoint> points;
  final List<String> labels;

  _HourlyChartPainter({required this.points, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final n = points.length;
    if (n < 2) {
      return;
    }

    const double padTop = 20;
    const double padBottom = 26;
    final double chartH = size.height - padTop - padBottom;

    double minT = points.first.temperature;
    double maxT = points.first.temperature;
    for (final p in points) {
      if (p.temperature < minT) {
        minT = p.temperature;
      }
      if (p.temperature > maxT) {
        maxT = p.temperature;
      }
    }
    minT = math.min(minT, maxT - 6) - 1;
    maxT = maxT + 3;
    final double rangeT = (maxT - minT).clamp(1.0, double.infinity);

    final double stepX = size.width / (n - 1);

    Offset pointAt(int i) {
      final double x = i * stepX;
      final double t = points[i].temperature;
      final double y = padTop + (maxT - t) / rangeT * chartH;
      return Offset(x, y);
    }

    // Smooth temperature path (midpoint quadratic curves).
    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < n; i++) {
      final a = pointAt(i - 1);
      final b = pointAt(i);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
    }
    path.lineTo(pointAt(n - 1).dx, pointAt(n - 1).dy);

    final fillPath = Path.from(path)
      ..lineTo(size.width, padTop + chartH)
      ..lineTo(0, padTop + chartH)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x66FF9E80), Color(0x00FF9E80)],
      ).createShader(Rect.fromLTWH(0, padTop, size.width, chartH + padBottom));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFFE57373)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Tick labels every 3 hours (plus the last point).
    for (var i = 0; i < n; i++) {
      final bool isTick = i % 3 == 0 || i == n - 1;
      if (!isTick) {
        continue;
      }
      final p = pointAt(i);

      _drawText(
        canvas,
        "${points[i].temperature.round()}°",
        Offset(p.dx, math.max(2, p.dy - 18)),
        anchorCenter: true,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      );

      // Droplet + precipitation probability (skipped when dry).
      final pop = points[i].precipProbability;
      if (pop >= 10) {
        double dropY = math.min(padTop + chartH - 4, p.dy + 14);
        final dy = size.height - 16;
        if (dropY > dy - 8) {
          dropY = dy - 12;
        }
        final dropPaint = Paint()..color = const Color(0xFF60A5FA);
        canvas.drawCircle(Offset(p.dx - 8, dropY + 2), 2.4, dropPaint);
        final dropTop = Path()
          ..moveTo(p.dx - 8, dropY - 1)
          ..lineTo(p.dx - 10.2, dropY - 4)
          ..lineTo(p.dx - 5.8, dropY - 4)
          ..close();
        canvas.drawPath(dropTop, dropPaint);
        _drawText(
          canvas,
          "$pop%",
          Offset(p.dx + 0, dropY + 2),
          anchorCenter: false,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
        );
      }

      _drawText(
        canvas,
        i < labels.length ? labels[i] : "",
        Offset(p.dx, size.height - 16),
        anchorCenter: i != 0 && i != n - 1,
        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    required bool anchorCenter,
    required TextStyle style,
  }) {
    final builder = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    builder.layout();
    final Offset origin = anchorCenter
        ? Offset(position.dx - builder.width / 2, position.dy)
        : position;
    builder.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(covariant _HourlyChartPainter oldDelegate) =>
      oldDelegate.points.length != points.length;
}

/// Colored arc gauge used by the AQI and UV tiles. Draws a muted track,
/// a multi-color sweep band, and a white-ringed marker dot at the value.
class _GaugePainter extends CustomPainter {
  final double? value;
  final double min;
  final double max;
  final List<Color> colors;

  _GaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.colors,
  });

  static const double _startAngle = 135 * math.pi / 180;
  static const double _sweep = 270 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) / 2;

    final gradient = SweepGradient(
      startAngle: _startAngle,
      endAngle: _startAngle + _sweep,
      colors: [
        ...colors,
        colors.last.withValues(alpha: 0.0),
      ],
      transform: const GradientRotation(0),
    );

    final band = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.32
      ..strokeCap = StrokeCap.round;
    final bandRect = Rect.fromCircle(center: center, radius: radius * 0.78);
    canvas.drawArc(bandRect, _startAngle, _sweep, false, band);

    if (value != null) {
      final fraction = ((value! - min) / (max - min)).clamp(0.02, 0.98);
      final angle = _startAngle + fraction * _sweep;
      final dotPos = Offset(
        center.dx + math.cos(angle) * radius * 0.78,
        center.dy + math.sin(angle) * radius * 0.78,
      );
      canvas.drawCircle(dotPos, radius * 0.16, Paint()..color = Colors.white);
      canvas.drawCircle(
        dotPos,
        radius * 0.12,
        Paint()..color = const Color(0xFF1E293B),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.value != value;
}

/// Wind compass with a needle pointing at the wind direction (0° = north).
class _CompassPainter extends CustomPainter {
  final double direction;

  _CompassPainter({required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;

    final ring = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, ring);

    _drawLabel(canvas, "W", Offset(radius * 0.14, 0) + center);
    _drawLabel(canvas, "N", Offset(0, -radius * 0.14) + center);
    _drawLabel(canvas, "E", Offset(-radius * 0.14, 0) + center);
    _drawLabel(canvas, "S", Offset(0, radius * 0.14) + center);

    final screenAngle = (direction - 90) * math.pi / 180;
    final tip = Offset(
      center.dx + math.cos(screenAngle) * radius * 0.78,
      center.dy + math.sin(screenAngle) * radius * 0.78,
    );
    final left = Offset(
      center.dx + math.cos(screenAngle + math.pi / 2) * radius * 0.3,
      center.dy + math.sin(screenAngle + math.pi / 2) * radius * 0.3,
    );
    final right = Offset(
      center.dx + math.cos(screenAngle - math.pi / 2) * radius * 0.3,
      center.dy + math.sin(screenAngle - math.pi / 2) * radius * 0.3,
    );
    final tail = Offset(
      center.dx - math.cos(screenAngle) * radius * 0.35,
      center.dy - math.sin(screenAngle) * radius * 0.35,
    );
    final needle = Paint()..color = const Color(0xFF60A5FA);
    final path = Path()..addPolygon([tip, left, tail], true);
    canvas.drawPath(path, needle);
    final path2 = Path()..addPolygon([tip, right, tail], true);
    canvas.drawPath(path2, needle);
  }

  void _drawLabel(Canvas canvas, String letter, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) => oldDelegate.direction != direction;
}

/// Decorative equalizer-style bar graphic for the humidity tile.
class _HumidityBars extends StatelessWidget {
  static const List<double> _heights = [
    0.55, 0.8, 0.45, 0.7, 0.6, 0.85, 0.5, 0.75, 0.65, 0.4,
  ];

  const _HumidityBars({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in _heights)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Container(
              width: 5,
              height: 26 * h,
              decoration: BoxDecoration(
                color: const Color(0xFF60A5FA),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
      ],
    );
  }
}
