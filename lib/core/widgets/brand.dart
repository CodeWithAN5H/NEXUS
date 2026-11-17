import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The NEXUS mark: a stylised angular "A" in the accent gradient.
class NexusMark extends StatelessWidget {
  const NexusMark({this.size = 28, this.glow = false, super.key});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: AppDecorations.accentGradient,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: size * 0.6,
                  offset: Offset(0, size * 0.15),
                ),
              ]
            : null,
      ),
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.24)
      ..lineTo(size.width * 0.76, size.height * 0.76)
      ..lineTo(size.width * 0.62, size.height * 0.76)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.38, size.height * 0.76)
      ..lineTo(size.width * 0.24, size.height * 0.76)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => false;
}

/// Wordmark used in the Home header and the desktop sidebar.
class NexusWordmark extends StatelessWidget {
  const NexusWordmark({this.size = 28, this.showTagline = false, super.key});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        NexusMark(size: size, glow: true),
        const SizedBox(width: AppSpacing.xs + 2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'NEXUS',
              style: AppTypography.headline.copyWith(
                fontSize: size * 0.72,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (showTagline)
              Text(
                'Stream. Discover. Enjoy.',
                style: AppTypography.caption.copyWith(fontSize: 10),
              ),
          ],
        ),
      ],
    );
  }
}
