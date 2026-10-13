import 'package:flutter/material.dart';

import 'ui/game_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnimalShadowApp());
}

class AnimalShadowApp extends StatelessWidget {
  const AnimalShadowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animal Shadow Match',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF9F0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF83BBAF),
        ),
      ),
      home: const GamePage(),
    );
  }
}
