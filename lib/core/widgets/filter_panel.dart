import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models/explore_filter.dart';
import '../../data/providers/content_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';
import 'chips.dart';
import 'states.dart';

/// Opens the explore filter sheet.
Future<void> showFilterPanel(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    builder: (BuildContext context) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ExploreFilter filter = ref.watch(exploreFilterProvider);
    final ExploreController controller = ref.read(
      exploreFilterProvider.notifier,
    );
    final AsyncValue<List<String>> genres = ref.watch(genresProvider);
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Text('Filters', style: AppTypography.sectionTitle),
                const Spacer(),
                TextButton(
                  onPressed: filter.hasActiveFilters
                      ? controller.clearFilters
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    disabledForegroundColor: AppColors.textMuted,
                  ),
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: <Widget>[
                _SectionLabel('Sort by'),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final ExploreSort sort in ExploreSort.values)
                      GenreChip(
                        label: sort.label,
                        selected: filter.sort == sort,
                        onTap: () => controller.setSort(sort),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel('Genre'),
                AsyncValueView<List<String>>(
                  value: genres,
                  compact: true,
                  onRetry: () => ref.invalidate(genresProvider),
                  loading: const LoadingSkeleton(height: 60),
                  builder: (BuildContext context, List<String> items) => Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final String genre in items)
                        GenreChip(
                          label: genre,
                          selected: filter.genres.contains(genre),
                          onTap: () => controller.toggleGenre(genre),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel('Season'),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final AnimeSeason season in AnimeSeason.values)
                      GenreChip(
                        label: season.label,
                        selected: filter.season == season,
                        onTap: () => controller.setSeason(
                          filter.season == season ? null : season,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel('Year'),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: exploreYears(DateTime.now()).length,
                    separatorBuilder: (BuildContext context, int _) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (BuildContext context, int index) {
                      final int year = exploreYears(DateTime.now())[index];
                      return GenreChip(
                        label: '$year',
                        selected: filter.year == year,
                        onTap: () => controller.setYear(
                          filter.year == year ? null : year,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SecondaryButton(
                      label: 'Reset',
                      expand: true,
                      onPressed: controller.reset,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Show results',
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontSize: 10.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
