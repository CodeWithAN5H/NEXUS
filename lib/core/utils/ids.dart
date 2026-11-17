/// Deterministic 32-bit FNV-1a hash.
///
/// Used to derive stable, negative local ids for provider series that have no
/// AniList id, so playback progress survives app restarts (unlike
/// `String.hashCode`, which is not guaranteed stable across runs).
int stableHash(String value) {
  int hash = 0x811C9DC5;
  for (final int unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// A stable negative id in a separate namespace from AniList's positive ids.
int localIdFor(String namespace, String value) {
  final int hash = stableHash('$namespace:$value') % 1000000;
  return -1000000 - hash;
}

/// True when [id] belongs to locally-defined content rather than AniList.
bool isLocalId(int id) => id < 0;
