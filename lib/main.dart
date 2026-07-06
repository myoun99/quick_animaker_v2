import 'package:flutter/material.dart';

import 'src/ui/home_page.dart';
import 'src/ui/theme/app_theme.dart';

void main() {
  runApp(const QuickAnimakerApp());
}

class QuickAnimakerApp extends StatelessWidget {
  const QuickAnimakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickAnimaker v2.1',
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}
