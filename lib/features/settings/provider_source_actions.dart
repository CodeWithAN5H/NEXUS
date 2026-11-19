import '../../integrations/providers/provider_state.dart';

/// An action a Sources card can offer.
enum ProviderAction { configure, enable, retry, testPlayback, details, remove }

/// The primary action for a state, plus the always-useful secondary actions.
///
/// [primary] is the one thing the card leads with — the action that can actually
/// change the state. [secondary] never repeats it.
class ProviderActionSet {
  const ProviderActionSet({
    required this.primary,
    this.secondary = const <ProviderAction>[],
  });

  final ProviderAction primary;
  final List<ProviderAction> secondary;

  List<ProviderAction> get all => <ProviderAction>[primary, ...secondary];

  bool contains(ProviderAction action) => all.contains(action);
}

/// Maps the existing three axes (via the derived presentation state) to the
/// actions that can succeed from that state.
///
/// UI policy only: it does not read a provider, a store or a keystore, so every
/// combination is testable without a widget or a database. Actions that cannot
/// work are simply absent — a disabled source offers no *Retry*, an
/// incompatible one offers no *Configure*.
abstract final class ProviderSourceActions {
  const ProviderSourceActions._();

  /// While a probe is still running there is no state to act on yet, so the card
  /// offers only inspection — never a misleading *Enable* or *Retry*.
  static ProviderActionSet forLoading({
    required bool isUserAdded,
    required bool hasConfiguration,
  }) {
    return ProviderActionSet(
      primary: ProviderAction.details,
      secondary: <ProviderAction>[
        if (hasConfiguration) ProviderAction.configure,
        if (isUserAdded) ProviderAction.remove,
      ],
    );
  }

  static ProviderActionSet forState({
    required ProviderPresentationState presentation,
    required bool isUserAdded,
    required bool hasConfiguration,
    required bool canTestPlayback,
  }) {
    final List<ProviderAction> secondary = <ProviderAction>[];

    void addSecondary(ProviderAction action) {
      if (!secondary.contains(action)) secondary.add(action);
    }

    switch (presentation) {
      case ProviderPresentationState.usable:
        addSecondary(ProviderAction.details);
        if (hasConfiguration) addSecondary(ProviderAction.configure);
        if (isUserAdded) addSecondary(ProviderAction.remove);
        return ProviderActionSet(
          primary: canTestPlayback
              ? ProviderAction.testPlayback
              : hasConfiguration
              ? ProviderAction.configure
              : ProviderAction.details,
          secondary: secondary,
        );

      case ProviderPresentationState.needsSetup:
        addSecondary(ProviderAction.details);
        if (isUserAdded) addSecondary(ProviderAction.remove);
        return ProviderActionSet(
          primary: hasConfiguration
              ? ProviderAction.configure
              : ProviderAction.details,
          secondary: secondary,
        );

      case ProviderPresentationState.rejectedConfiguration:
        addSecondary(ProviderAction.details);
        if (isUserAdded) addSecondary(ProviderAction.remove);
        return ProviderActionSet(
          primary: hasConfiguration
              ? ProviderAction.configure
              : ProviderAction.details,
          secondary: secondary,
        );

      case ProviderPresentationState.incompatible:
        addSecondary(ProviderAction.details);
        if (isUserAdded) {
          return ProviderActionSet(
            primary: ProviderAction.remove,
            secondary: secondary,
          );
        }
        return ProviderActionSet(
          primary: ProviderAction.details,
          secondary: const <ProviderAction>[],
        );

      case ProviderPresentationState.unavailable:
        addSecondary(ProviderAction.details);
        if (hasConfiguration) addSecondary(ProviderAction.configure);
        if (isUserAdded) addSecondary(ProviderAction.remove);
        return ProviderActionSet(
          primary: ProviderAction.retry,
          secondary: secondary,
        );

      case ProviderPresentationState.disabled:
        addSecondary(ProviderAction.details);
        if (hasConfiguration) addSecondary(ProviderAction.configure);
        if (isUserAdded) addSecondary(ProviderAction.remove);
        return ProviderActionSet(
          primary: ProviderAction.enable,
          secondary: secondary,
        );
    }
  }
}
