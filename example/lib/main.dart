import 'package:flutter/material.dart';
import 'package:unified_device_sdk/unified_device_sdk.dart';

import 'debug_console_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final bool enablePlatformBootstrap;
  final UnifiedDevicePlatform? platform;

  const MyApp({
    super.key,
    this.enablePlatformBootstrap = true,
    this.platform,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unified Device Debug Console',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C67),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F0E8),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          color: Colors.white,
        ),
      ),
      home: DebugConsoleScreen(
        platform: platform,
        enablePlatformBootstrap: enablePlatformBootstrap,
      ),
    );
  }
}
