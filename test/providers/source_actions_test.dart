import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/settings/provider_source_actions.dart';
import 'package:nexus/integrations/providers/provider_state.dart';

void main() {
  ProviderActionSet actions(
    ProviderPresentationState presentation, {
    bool isUserAdded = true,
    bool hasConfiguration = true,
    bool canTestPlayback = true,
  }) {
    return ProviderSourceActions.forState(
      presentation: presentation,
      isUserAdded: isUserAdded,
      hasConfiguration: hasConfiguration,
      canTestPlayback: canTestPlayback,
    );
  }

  group('while a check is running', () {
    test('offers inspection only, never a misleading action', () {
      final ProviderActionSet set = ProviderSourceActions.forLoading(
        isUserAdded: true,
        hasConfiguration: true,
      );
      expect(set.primary, ProviderAction.details);
      expect(set.contains(ProviderAction.configure), isTrue);
      expect(set.contains(ProviderAction.remove), isTrue);
      expect(set.contains(ProviderAction.enable), isFalse);
      expect(set.contains(ProviderAction.retry), isFalse);
      expect(set.contains(ProviderAction.testPlayback), isFalse);
    });
  });

  group('primary action per derived state', () {
    test('usable leads with playback, then configure and details', () {
      final ProviderActionSet set = actions(ProviderPresentationState.usable);
      expect(set.primary, ProviderAction.testPlayback);
      expect(set.secondary, contains(ProviderAction.configure));
      expect(set.secondary, contains(ProviderAction.details));
      expect(set.secondary, contains(ProviderAction.remove));
      expect(set.contains(ProviderAction.enable), isFalse);
      expect(set.contains(ProviderAction.retry), isFalse);
    });

    test('usable without search capability leads with configure', () {
      final ProviderActionSet set = actions(
        ProviderPresentationState.usable,
        canTestPlayback: false,
      );
      expect(set.primary, ProviderAction.configure);
      expect(set.contains(ProviderAction.testPlayback), isFalse);
    });

    test('usable without configuration fields leads with details', () {
      final ProviderActionSet set = actions(
        ProviderPresentationState.usable,
        canTestPlayback: false,
        hasConfiguration: false,
      );
      expect(set.primary, ProviderAction.details);
      expect(set.contains(ProviderAction.configure), isFalse);
    });

    test('needsSetup leads with configure and never offers playback', () {
      final ProviderActionSet set = actions(
        ProviderPresentationState.needsSetup,
      );
      expect(set.primary, ProviderAction.configure);
      expect(set.contains(ProviderAction.testPlayback), isFalse);
      expect(set.contains(ProviderAction.retry), isFalse);
    });

    test('rejected credentials lead back to configure', () {
      final ProviderActionSet set = actions(
        ProviderPresentationState.rejectedConfiguration,
      );
      expect(set.primary, ProviderAction.configure);
      expect(set.contains(ProviderAction.testPlayback), isFalse);
    });

    test('incompatible user source can only be removed or inspected', () {
      final ProviderActionSet set = actions(
        ProviderPresentationState.incompatible,
      );
      expect(set.primary, ProviderAction.remove);
      expect(set.contains(ProviderAction.details), isTrue);
      expect(set.contains(ProviderAction.configure), isFalse);
      expect(set.contains(ProviderAction.testPlayback), isFalse);
      expect(set.contains(ProviderAction.retry), isFalse);
    });

    test('incompatible built-in source is inspect-only', () {
      final ProviderActionSet set = actions(
        ProviderPresentationState.incompatible,
        isUserAdded: false,
      );
      expect(set.primary, ProviderAction.details);
      expect(set.contains(ProviderAction.remove), isFalse);
    });

    test('unavailable leads with retry', () {
      final ProviderActionSet set = actions(
        ProviderPresentationState.unavailable,
      );
      expect(set.primary, ProviderAction.retry);
      expect(set.contains(ProviderAction.configure), isTrue);
      expect(set.contains(ProviderAction.testPlayback), isFalse);
      expect(set.contains(ProviderAction.remove), isTrue);
    });

    test('disabled leads with enable and offers no retry or playback', () {
      final ProviderActionSet set = actions(ProviderPresentationState.disabled);
      expect(set.primary, ProviderAction.enable);
      expect(set.contains(ProviderAction.retry), isFalse);
      expect(set.contains(ProviderAction.testPlayback), isFalse);
      expect(set.contains(ProviderAction.configure), isTrue);
      expect(set.contains(ProviderAction.remove), isTrue);
    });

    test('built-in sources never expose removal', () {
      for (final ProviderPresentationState presentation
          in ProviderPresentationState.values) {
        final ProviderActionSet set = actions(presentation, isUserAdded: false);
        expect(set.contains(ProviderAction.remove), isFalse);
      }
    });

    test('the primary action is never repeated in the secondary list', () {
      for (final ProviderPresentationState presentation
          in ProviderPresentationState.values) {
        for (final bool isUserAdded in <bool>[true, false]) {
          final ProviderActionSet set = actions(
            presentation,
            isUserAdded: isUserAdded,
          );
          expect(set.secondary, isNot(contains(set.primary)));
          expect(set.all.toSet().length, set.all.length);
        }
      }
    });
  });
}
