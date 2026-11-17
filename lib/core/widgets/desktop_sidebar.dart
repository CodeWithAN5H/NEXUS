import 'package:material_ui/material_ui.dart';

import '../../app/navigation_destinations.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'brand.dart';

/// Persistent desktop sidebar.
///
/// Windows keeps navigation on the left with a wider hit area and hover states,
/// rather than stretching the phone bottom bar.
class NexusSidebar extends StatelessWidget {
  const NexusSidebar({
    required this.destinations,
    required this.activeBranchIndex,
    required this.onSelect,
    this.onOpenProfile,
    super.key,
  });

  final List<AppDestination> destinations;
  final int activeBranchIndex;
  final ValueChanged<AppDestination> onSelect;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg + 4,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: GestureDetector(
              onTap: onOpenProfile,
              child: const NexusWordmark(size: 30, showTagline: true),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: <Widget>[
                for (final AppDestination destination in destinations)
                  _SidebarTile(
                    destination: destination,
                    selected: _isSelected(destination),
                    onTap: () => onSelect(destination),
                  ),
              ],
            ),
          ),
          const _SidebarFooter(),
        ],
      ),
    );
  }

  bool _isSelected(AppDestination destination) {
    if (destination.branchIndex == activeBranchIndex) return true;
    // History and Settings keep Profile highlighted only on the mobile bar, so
    // the desktop sidebar always reflects the exact destination.
    return false;
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.14)
                  : (_hovered
                        ? AppColors.surfaceSecondary
                        : AppColors.transparent),
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  active
                      ? widget.destination.activeIcon
                      : widget.destination.icon,
                  size: 19,
                  color: active ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Text(
                  widget.destination.label,
                  style: AppTypography.bodyStrong.copyWith(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'NEXUS ${AppConstants.appVersion}',
              style: AppTypography.caption.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
