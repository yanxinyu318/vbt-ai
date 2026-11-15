import 'package:flutter/material.dart';
import 'package:vbt/features/home/presentation/home_screen.dart';
import 'theme.dart';

class VBTApp extends StatelessWidget {
  const VBTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '杠铃速度追踪',
      debugShowCheckedModeBanner: false,
      theme: vbtTheme,
      home: const HomeScreen(),
    );
  }
}
