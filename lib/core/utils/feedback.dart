import 'package:material_ui/material_ui.dart';

import '../errors/app_failure.dart';
import '../theme/app_colors.dart';

/// Shows a short, themed confirmation message.
void showNexusMessage(
  BuildContext context,
  String message, {
  bool isError = false,
  SnackBarAction? action,
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 18,
              color: isError ? AppColors.error : AppColors.success,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        action: action,
        duration: const Duration(seconds: 3),
      ),
    );
}

/// Shows a failure message, preferring the user-facing text of an [AppFailure].
void showNexusFailure(BuildContext context, Object error) {
  final AppFailure failure = AppFailure.from(error);
  showNexusMessage(context, failure.message, isError: true);
}
