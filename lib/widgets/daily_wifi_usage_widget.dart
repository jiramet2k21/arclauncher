import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DailyWifiUsageWidget extends StatefulWidget {
  const DailyWifiUsageWidget({super.key});

  @override
  State<DailyWifiUsageWidget> createState() => _DailyWifiUsageWidgetState();
}

class _DailyWifiUsageWidgetState extends State<DailyWifiUsageWidget> {
  String _period = "daily";
  Future<int>? _usageFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final period = context.read<SettingsService>().wifiUsagePeriod;
    if (period != _period || _usageFuture == null) {
      _period = period;
      _usageFuture = context.read<NetworkService>().getWifiUsageForPeriod(period);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NetworkService, SettingsService>(
      builder: (context, networkService, settingsService, _) {
        if (!networkService.hasUsageStatsPermission) {
          return TextButton.icon(
             icon: const Icon(Icons.data_usage, size: 20),
             label: const Text("Grant Usage Permission"),
             onPressed: () => networkService.requestPermission(),
          );
        }

        if (settingsService.wifiUsagePeriod != _period) {
          _period = settingsService.wifiUsagePeriod;
          _usageFuture = networkService.getWifiUsageForPeriod(_period);
        }

        final period = _period;
        String label;
        switch (period) {
          case 'weekly':
            label = 'Weekly: ';
            break;
          case 'monthly':
            label = 'Monthly: ';
            break;
          case 'daily':
          default:
            label = 'Daily: ';
            break;
        }

        return FutureBuilder<int>(
          future: _usageFuture,
          builder: (context, snapshot) {
            final usage = snapshot.data ?? networkService.dailyWifiUsage;
            final usageString = _formatBytes(usage);

            return RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)
                  ],
                ),
                children: [
                  TextSpan(text: label),
                  TextSpan(
                    text: usageString,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return "${d.toStringAsFixed(2)} ${suffixes[i]}";
  }
}
