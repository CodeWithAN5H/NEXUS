import 'dart:async';

import '../../integrations/providers/provider_record.dart';
import '../../integrations/providers/provider_descriptor.dart';
import '../repositories/provider_store.dart';
import 'provider_lifecycle_service.dart';

/// Mutations that read and rewrite provider rows, serialised through one queue.
///
/// Reordering is a read-modify-write of every priority, so two quick taps could
/// otherwise both read the old order and one would be lost. Every operation here
/// waits for the previous one and then reads fresh state, so the database always
/// holds one complete, duplicate-free order.
class ProviderManagementService {
  ProviderManagementService(this._store, this._lifecycle);

  final ProviderStore _store;
  final ProviderLifecycleService _lifecycle;

  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  /// Moves one user-added provider [delta] places within the user-added order.
  ///
  /// Built-in rows are included when priorities are written — ahead of the user
  /// rows, in their existing relative order — so every row ends up with a
  /// distinct priority and a built-in never becomes user-managed. Moving past
  /// either end is a no-op that does not rewrite anything.
  Future<List<String>> moveUserProvider(
    String providerId, {
    required int delta,
  }) {
    return _serial(() async {
      final List<ProviderRecord> records = await _store.loadAll();
      final List<String> builtIns = <String>[
        for (final ProviderRecord record in records)
          if (record.origin == ProviderOrigin.builtIn) record.providerId,
      ];
      final List<String> users = <String>[
        for (final ProviderRecord record in records)
          if (record.origin == ProviderOrigin.userAdded) record.providerId,
      ];

      final int index = users.indexOf(providerId);
      if (index < 0) {
        throw const ProviderLifecycleFailure(
          'That source is not installed.',
          code: 'provider.notInstalled',
        );
      }
      final int target = index + delta;
      if (target < 0 || target >= users.length) {
        return List<String>.unmodifiable(users);
      }

      final String moved = users.removeAt(index);
      users.insert(target, moved);
      await _store.setPriority(<String>[...builtIns, ...users]);
      return List<String>.unmodifiable(users);
    });
  }

  /// Enable/disable through the lifecycle service, serialised with reordering so
  /// a toggle cannot interleave with a priority rewrite.
  Future<void> setEnabled(String providerId, bool enabled) {
    return _serial(() => _lifecycle.setEnabled(providerId, enabled));
  }
}
