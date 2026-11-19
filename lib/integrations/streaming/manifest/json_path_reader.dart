/// The read-only JSON path subset of `docs/PROVIDER_MANIFEST.md` §6.3.
///
/// Supported: `$`, `.key`, `["key"]`, `[3]`, and one trailing `[*]`.
/// Refused: recursive descent, filters, slices, unions, functions and any path
/// deeper than 8 segments or longer than 256 characters. This is a selector
/// over an already-parsed document — it never evaluates anything.
library;

sealed class _Segment {
  const _Segment();
}

final class _KeySegment extends _Segment {
  const _KeySegment(this.key);
  final String key;
}

final class _IndexSegment extends _Segment {
  const _IndexSegment(this.index);
  final int index;
}

final class _WildcardSegment extends _Segment {
  const _WildcardSegment();
}

/// A parsed JSON path.
class JsonPath {
  JsonPath._(this.source, this._segments, this.hasWildcard);

  /// Maximum segments after `$`.
  static const int maxSegments = 8;

  /// Maximum source length in characters.
  static const int maxLength = 256;

  static final RegExp _key = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,63}$');
  static final RegExp _quotedKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_ .-]{0,63}$');
  static final RegExp _index = RegExp(r'^\d{1,4}$');

  final String source;
  final List<_Segment> _segments;

  /// Whether the path ends with the single allowed wildcard.
  final bool hasWildcard;

  /// Parses [source], or returns `null` when it is outside the subset.
  static JsonPath? tryParse(String source) {
    if (source.length > maxLength) return null;
    if (!source.startsWith(r'$')) return null;

    final List<_Segment> segments = <_Segment>[];
    int i = 1;
    bool wildcard = false;
    while (i < source.length) {
      if (wildcard) return null; // nothing may follow `[*]`
      final String rest = source.substring(i);
      if (rest.startsWith('.')) {
        if (rest.startsWith('..')) return null; // recursive descent
        final int end = source.indexOf(RegExp(r'[.\[]'), i + 1);
        final String key = source.substring(
          i + 1,
          end == -1 ? source.length : end,
        );
        if (!_key.hasMatch(key)) return null;
        segments.add(_KeySegment(key));
        i = end == -1 ? source.length : end;
        continue;
      }
      if (rest.startsWith('[')) {
        final int close = source.indexOf(']', i);
        if (close == -1) return null;
        final String inner = source.substring(i + 1, close);
        if (inner == '*') {
          wildcard = true;
        } else if (inner.startsWith('"') || inner.startsWith("'")) {
          if (inner.length < 3) return null;
          final String quote = inner[0];
          if (!inner.endsWith(quote)) return null;
          final String key = inner.substring(1, inner.length - 1);
          if (!_quotedKey.hasMatch(key)) return null;
          segments.add(_KeySegment(key));
        } else if (_index.hasMatch(inner)) {
          segments.add(_IndexSegment(int.parse(inner)));
        } else {
          // Filters, slices, unions, functions and anything else.
          return null;
        }
        i = close + 1;
        continue;
      }
      return null;
    }

    if (segments.length > maxSegments) return null;
    return JsonPath._(source, List<_Segment>.unmodifiable(segments), wildcard);
  }

  /// Reads one value. A wildcard yields its **first** match, which is what a
  /// `map` field means inside an item; use [readList] for list selection.
  Object? read(Object? root) {
    final Object? value = _resolve(root);
    if (!hasWildcard) return value;
    if (value is List && value.isNotEmpty) return value.first;
    return null;
  }

  /// Reads every value a `list` selection refers to.
  ///
  /// Returns `null` when nothing was found, an empty list when the document
  /// genuinely contains an empty list, and a non-list value as a single-item
  /// list only through [readSingleList] (the adapter rejects it instead).
  Object? readRaw(Object? root) => _resolve(root);

  /// `true` when the final segment is a wildcard.
  bool get selectsItems => hasWildcard;

  Object? _resolve(Object? root) {
    Object? current = root;
    for (int index = 0; index < _segments.length; index++) {
      final _Segment segment = _segments[index];
      switch (segment) {
        case _KeySegment(key: final String key):
          if (current is! Map) return null;
          current = current[key];
        case _IndexSegment(index: final int at):
          if (current is! List) return null;
          if (at < 0 || at >= current.length) return null;
          current = current[at];
        case _WildcardSegment():
          if (current is! List) return null;
          final List<Object?> rest = _collect(current, index + 1);
          return rest;
      }
    }
    return current;
  }

  List<Object?> _collect(Object? node, int from) {
    if (from >= _segments.length) return <Object?>[node];
    final _Segment segment = _segments[from];
    switch (segment) {
      case _WildcardSegment():
        if (node is! List) return const <Object?>[];
        final List<Object?> out = <Object?>[];
        for (final Object? item in node) {
          out.addAll(_collect(item, from + 1));
        }
        return out;
      case _KeySegment(key: final String key):
        if (node is! Map) return const <Object?>[];
        return _collect(node[key], from + 1);
      case _IndexSegment(index: final int at):
        if (node is! List || at < 0 || at >= node.length) {
          return const <Object?>[];
        }
        return _collect(node[at], from + 1);
    }
  }

  @override
  String toString() => source;
}
