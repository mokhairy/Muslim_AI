import 'package:flutter/material.dart';

import 'src/screens/shell_screen.dart';
import 'src/theme/app_theme.dart';

class MuslimAiApp extends StatelessWidget {
  const MuslimAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MuslimAI',
      debugShowCheckedModeBanner: false,
      theme: buildMuslimAiTheme(),
      home: const ShellScreen(),
    );
  }
}
