import 'package:flutter/material.dart';

void main() {
  runApp(const QuickAnimakerApp());
}

class QuickAnimakerApp extends StatelessWidget {
  const QuickAnimakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'QuickAnimaker v2.1',
      home: Scaffold(
        body: Center(
          child: Text('QuickAnimaker v2.1'),
        ),
      ),
    );
  }
}
