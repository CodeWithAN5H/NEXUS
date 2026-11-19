import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/integrations/providers/provider_descriptor.dart';
import 'package:nexus/integrations/providers/provider_state.dart';

const List<ProviderConfigField> _fields = <ProviderConfigField>[
  ProviderConfigField(key: 'baseUrl', label: 'Base URL', required: true),
  ProviderConfigField(key: 'region', label: 'Region'),
];

ProviderStatusSnapshot _snapshot(
  ProviderAvailability availability, {
  String message = 'Source message',
}) {
  return ProviderStatusSnapshot(
    availability: availability,
    message: message,
    observedAt: DateTime(2026, 11, 19),
  );
}

ProviderState _state({
  ProviderCompatibility compatibility = ProviderCompatibility.compatible,
  ProviderConfigurationState configuration =
      ProviderConfigurationState.notRequired,
  ProviderAvailability availability = ProviderAvailability.ready,
  bool enabled = true,
  List<String> missing = const <String>[],
}) {
  return ProviderState(
    providerId: 'test',
    kind: ProviderKind.streaming,
    compatibility: compatibility,
    configuration: configuration,
    availability: _snapshot(availability),
    enabled: enabled,
    missingConfigurationKeys: missing,
  );
}

void main() {
  group('T-S01 configuration axis', () {
    test('no declared fields means notRequired', () {
      expect(
        ProviderConfigurationState.evaluate(
          const <ProviderConfigField>[],
          const <String, String>{},
        ),
        ProviderConfigurationState.notRequired,
      );
    });

    test('a missing required value means incomplete', () {
      expect(
        ProviderConfigurationState.evaluate(_fields, const <String, String>{}),
        ProviderConfigurationState.incomplete,
      );
      expect(
        ProviderConfigurationState.evaluate(_fields, <String, String>{
          'baseUrl': '   ',
        }),
        ProviderConfigurationState.incomplete,
      );
    });

    test('all required values present means configured', () {
      expect(
        ProviderConfigurationState.evaluate(_fields, <String, String>{
          'baseUrl': 'https://api.example.com',
        }),
        ProviderConfigurationState.configured,
      );
    });

    test('missing keys are named for the UI', () {
      expect(
        ProviderConfigurationState.missingKeys(_fields, const <String, String>{
          'region': 'eu',
        }),
        <String>['baseUrl'],
      );
    });
  });

  group('T-S01 derived presentation state', () {
    test('usable when every axis allows it', () {
      final ProviderState state = _state();
      expect(state.presentation, ProviderPresentationState.usable);
      expect(state.isUsable, isTrue);
      expect(state.offersRetry, isFalse);
      expect(state.message, 'Source message');
    });

    test('limited availability is still usable', () {
      expect(
        _state(availability: ProviderAvailability.limited).presentation,
        ProviderPresentationState.usable,
      );
      expect(
        _state(availability: ProviderAvailability.degraded).presentation,
        ProviderPresentationState.usable,
      );
    });

    test('needs setup when a required field is empty', () {
      final ProviderState state = _state(
        configuration: ProviderConfigurationState.incomplete,
        missing: <String>['baseUrl'],
      );
      expect(state.presentation, ProviderPresentationState.needsSetup);
      expect(state.message, contains('baseUrl'));
      expect(state.offersRetry, isFalse);
    });

    test('rejected configuration is its own state', () {
      final ProviderState state = _state(
        configuration: ProviderConfigurationState.rejected,
      );
      expect(
        state.presentation,
        ProviderPresentationState.rejectedConfiguration,
      );
      expect(state.offersRetry, isFalse);
    });

    test('incompatible wins over every user-fixable state', () {
      final ProviderState state = _state(
        compatibility: ProviderCompatibility.requiresNewerApp,
        configuration: ProviderConfigurationState.incomplete,
        enabled: false,
      );
      expect(state.presentation, ProviderPresentationState.incompatible);
      expect(state.message, contains('newer NEXUS'));
      expect(state.offersRetry, isFalse);
    });

    test('platform incompatibility explains itself', () {
      expect(
        _state(compatibility: ProviderCompatibility.unsupportedPlatform)
            .message,
        contains('platform'),
      );
    });

    test('unavailable is the only retryable state', () {
      final ProviderState state = _state(
        availability: ProviderAvailability.unavailable,
      );
      expect(state.presentation, ProviderPresentationState.unavailable);
      expect(state.offersRetry, isTrue);
    });

    test('disabled keeps configuration and reports Off', () {
      final ProviderState state = _state(enabled: false);
      expect(state.presentation, ProviderPresentationState.disabled);
      expect(state.message, contains('configuration is kept'));
      expect(state.offersRetry, isFalse);
    });
  });

  group('T-A04 snapshot', () {
    test(
      'an unprobed snapshot is unavailable and timestamped at the epoch',
      () {
        final ProviderStatusSnapshot snapshot =
            ProviderStatusSnapshot.unprobed();
        expect(snapshot.availability, ProviderAvailability.unavailable);
        expect(snapshot.canServe, isFalse);
        expect(snapshot.observedAt.millisecondsSinceEpoch, 0);
      },
    );
  });
}
