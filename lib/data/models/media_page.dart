import 'anime.dart';

/// One page of metadata results.
///
/// Deliberately provider-neutral: it lived in the AniList client in v0.1, which
/// is exactly the coupling the `MetadataProvider` interface removes. It has no
/// provider-specific fields, so a second catalogue can return it unchanged.
class MediaPage {
  const MediaPage({
    required this.items,
    required this.hasNextPage,
    this.total = 0,
  });

  const MediaPage.empty()
    : items = const <Anime>[],
      hasNextPage = false,
      total = 0;

  final List<Anime> items;
  final bool hasNextPage;
  final int total;

  bool get isEmpty => items.isEmpty;
}
