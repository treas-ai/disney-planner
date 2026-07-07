import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(const DisneyPlannerApp());
}

class DisneyPlannerApp extends StatelessWidget {
  const DisneyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Disney Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A5ACD),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}