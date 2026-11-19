import 'package:dio/dio.dart';

import '../anilist/anilist_metadata_provider.dart';
import '../streaming/sample_provider.dart';
import '../streaming/streaming_provider.dart';
import 'metadata_provider.dart';
import 'provider_registries.dart';

/// The single place where providers are registered — two lists, one file.
///
/// Adding a streaming provider is one entry in [buildStreamingProviderRegistry];
/// no screen, repository, route or schema change is required. Adding a metadata
/// catalogue is one entry here too, and `MetadataRepository` picks it up.
StreamingProviderRegistry buildStreamingProviderRegistry() {
  return StreamingProviderRegistry(<StreamingProvider>[
    const SamplePlaybackProvider(),
  ]);
}

MetadataProviderRegistry buildMetadataProviderRegistry(Dio dio) {
  return MetadataProviderRegistry(<MetadataProvider>[
    AniListMetadataProvider.withDio(dio),
  ]);
}
