import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/desktop_sidebar.dart';
import '../core/widgets/navigation_bar.dart';
import '../core/widgets/responsive.dart';
import 'navigation_destinations.dart';

/// The adaptive application shell.
///
/// Android and small windows get the bottom bar; Windows and wide windows get
/// the persistent sidebar. Both drive the same [StatefulNavigationShell], so
/// per-tab state survives switching.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool desktop = context.usesDesktopShell;

    if (desktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: <Widget>[
            NexusSidebar(
              destinations: desktopDestinations,
              activeBranchIndex: navigationShell.currentIndex,
              onSelect: (AppDestination destination) =>
                  _goBranch(destination.branchIndex),
              onOpenProfile: () => _goBranch(profileDestination.branchIndex),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: NexusBottomBar(
        destinations: mobileDestinations,
        activeBranchIndex: navigationShell.currentIndex,
        onSelect: (AppDestination destination) =>
            _goBranch(destination.branchIndex),
      ),
    );
  }
}
