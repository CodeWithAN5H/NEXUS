import 'sample_provider.dart';
import 'source_manager.dart';
import 'streaming_provider.dart';

/// The single place where content providers are registered.
///
/// Adding an authorised provider is a one-line change:
/// `ProviderRegistry(<StreamingProvider>[const SamplePlaybackProvider(), MyProvider()])`.
/// No screen, repository or route needs to be touched.
ProviderRegistry buildProviderRegistry() {
  return const ProviderRegistry(<StreamingProvider>[SamplePlaybackProvider()]);
}
