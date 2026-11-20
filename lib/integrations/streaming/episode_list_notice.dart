/// Optional provider-side note about the episode list it just produced.
///
/// A provider that can return a *partial* list — because a later page of an
/// upstream paginated list failed — implements this so the details screen can
/// say so. Returning `null` means the most recent list was complete.
///
/// This is a separate interface rather than a new capability: providers that
/// always return a complete list keep implementing nothing extra, and no
/// existing contract changes.
library;

abstract interface class EpisodeListNotice {
  /// A sentence for the user, or `null` when [seriesId] is complete.
  String? episodeNotice(String seriesId);
}
