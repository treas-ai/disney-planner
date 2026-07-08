import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'main_shell.dart';

class DisneyPlannerApp extends StatelessWidget {
  const DisneyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Disney Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainShell(),
    );
  }
}