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
    // The theme rides the LIVE accent settings (UI-R22 #5): changing
    // accent 1/2 rebuilds the app under a fresh scheme.
    return ValueListenableBuilder(
      valueListenable: AppColors.accentSettings,
      builder: (context, _, _) => MaterialApp(
        title: 'QuickAnimaker',
        theme: buildAppTheme(),
        home: const HomePage(),
      ),
    );
  }
}
