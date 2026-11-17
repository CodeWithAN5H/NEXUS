import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';

/// NEXUS entry point.
///
/// `MediaKit.ensureInitialized()` loads the native playback libraries; on
/// Android it is a no-op, on Windows it binds libmpv before any player is built.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: NexusApp()));
}
