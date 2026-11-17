import 'package:material_ui/material_ui.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

/// Root widget. A single dark theme ships in v0.1.
class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: appRouter,
      builder: (BuildContext context, Widget? child) {
        // Users may scale text; clamp so layouts stay intact rather than
        // overflowing, but still honour a meaningful increase.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
          child: ColoredBox(
            color: AppColors.background,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
