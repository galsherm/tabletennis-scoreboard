import 'package:flutter/material.dart';

import 'screens/setup_screen.dart';

void main() {
  runApp(const TableTennisScoreboardApp());
}

class TableTennisScoreboardApp extends StatelessWidget {
  const TableTennisScoreboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Table Tennis Scoreboard',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const SetupScreen(),
    );
  }
}
