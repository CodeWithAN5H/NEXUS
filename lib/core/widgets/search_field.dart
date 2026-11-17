import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Search input used on Explore and in the Home header.
class NexusSearchField extends StatefulWidget {
  const NexusSearchField({
    required this.controller,
    this.hintText = 'Search anime…',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.onTap,
    this.readOnly = false,
    this.dense = false,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool dense;

  @override
  State<NexusSearchField> createState() => _NexusSearchFieldState();
}

class _NexusSearchFieldState extends State<NexusSearchField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focused != _focusNode.hasFocus) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      height: widget.dense ? 42 : 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(
          color: _focused ? AppColors.accentMuted : AppColors.border,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.search_rounded,
            size: 19,
            color: _focused ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyStrong,
              cursorColor: AppColors.accent,
              cursorWidth: 1.6,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.textMuted,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (BuildContext context, TextEditingValue value, Widget? _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  widget.controller.clear();
                  widget.onChanged?.call('');
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.xs),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
