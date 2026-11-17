import 'package:material_ui/material_ui.dart';

import '../../app/navigation_destinations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The persistent Android bottom navigation.
///
/// Deliberately custom rather than Material's [NavigationBar]: the approved
/// design uses a quieter, icon-led bar with a soft active pill.
class NexusBottomBar extends StatelessWidget {
  const NexusBottomBar({
    required this.destinations,
    required this.activeBranchIndex,
    required this.onSelect,
    super.key,
  });

  final List<AppDestination> destinations;

  /// Branch index of the shell that is currently visible. Destinations in the
  /// same family (Profile / History / Settings) highlight together.
  final int activeBranchIndex;

  final ValueChanged<AppDestination> onSelect;

  int get _activeIndex {
    for (int i = 0; i < destinations.length; i++) {
      final AppDestination destination = destinations[i];
      if (destination.branchIndex == activeBranchIndex) return i;
    }
    if (profileFamilyBranches.contains(activeBranchIndex)) {
      for (int i = 0; i < destinations.length; i++) {
        if (destinations[i].branchIndex == profileDestination.branchIndex) {
          return i;
        }
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int active = _activeIndex;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < destinations.length; i++)
                Expanded(
                  child: _BottomBarItem(
                    destination: destinations[i],
                    selected: i == active,
                    onTap: () => onSelect(destinations[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.accent : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.transparent,
        highlightColor: AppColors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: AppDurations.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.14)
                    : AppColors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 21,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: AppTypography.caption.copyWith(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
