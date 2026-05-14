import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/screens/shell_screen.dart';
import 'src/theme/app_theme.dart';

class MuslimAiApp extends StatelessWidget {
  const MuslimAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MuslimAI',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: buildMuslimAiTheme(),
      home: const ShellScreen(),
    );
  }
}
