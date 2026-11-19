import 'package:flutter/services.dart';

/// Suppresses screen capture while credential fields are on screen.
///
/// Android only, via `FLAG_SECURE` on the activity. Everywhere else this is a
/// no-op and NEXUS makes no claim about screenshots or screen recording there:
/// the plugin-independent `screen_protector`-style features are out of scope for
/// this milestone.
class SecureScreen {
  const SecureScreen._();

  static const MethodChannel _channel = MethodChannel(
    'app.nexus/secure_screen',
  );

  /// Best effort: a missing channel (tests, desktop, older builds) is ignored so
  /// a credential screen never fails to open because of this call.
  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setSecure', <String, Object?>{
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Desktop, tests and non-Android platforms have no activity flag.
    } on PlatformException {
      // Never block the form on a platform quirk.
    }
  }
}
