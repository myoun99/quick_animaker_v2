import 'package:flutter/material.dart';

import 'src/services/input/pen_sidecars.dart';
import 'src/ui/home_page.dart';
import 'src/ui/input/app_input_settings.dart' show AppInput;
import 'src/ui/theme/app_theme.dart';

void main() {
  // The pen sidecars (PEN-2/PEN-4): Wintab follows the input settings;
  // the macOS/Linux channel streams start on their platform. Absent
  // drivers/handlers stay permanently idle.
  PenSidecars.bind();
  runApp(const QuickAnimakerApp());
}

class QuickAnimakerApp extends StatelessWidget {
  const QuickAnimakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The theme rides the LIVE accent settings (UI-R22 #5) and the
    // pointer-input policy (UI-R22 #6): changing either rebuilds the app
    // so gesture device sets and scroll behaviors re-derive.
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppColors.accentSettings,
        AppInput.settings,
      ]),
      builder: (context, _) => MaterialApp(
        title: 'QuickAnimaker',
        theme: buildAppTheme(),
        home: const HomePage(),
      ),
    );
  }
}
