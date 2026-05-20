import 'package:flutter_dotenv/flutter_dotenv.dart';

/// OAuth Web client for [google_sign_in] (Calendar link on web).
///
/// Must be the **Web client** from Google Cloud project **booqlyapp-83777**
/// (client ID starts with `87414724762-`). Not iOS/Android clients, not a
/// different GCP project (e.g. `982263059367-...`).
class GoogleOAuthConfig {
  GoogleOAuthConfig._();

  /// Firebase / GCP project number for booqlyapp-83777.
  static const firebaseProjectNumber = '87414724762';

  static String? get webClientId {
    const fromDefine = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    final fromEnv = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return null;
  }

  static bool get hasWebClientId => webClientId != null;

  /// True when the ID belongs to booqlyapp-83777 (not "My First Project", etc.).
  static bool get isBooqlyWebClient {
    final id = webClientId;
    if (id == null) return false;
    return id.startsWith('$firebaseProjectNumber-');
  }

  static String? get mismatchMessage {
    if (!hasWebClientId) {
      return 'Add GOOGLE_WEB_CLIENT_ID to assets/config.env.\n\n'
          'Firebase Console → Authentication → Sign-in method → Google → '
          'copy the Web client ID (starts with $firebaseProjectNumber-).\n'
          'Then run: .\\scripts\\sync-google-oauth.ps1';
    }
    if (!isBooqlyWebClient) {
      return 'GOOGLE_WEB_CLIENT_ID is from the wrong Google Cloud project.\n\n'
          'Current value starts with "${webClientId!.split('-').first}-".\n'
          'It must start with "$firebaseProjectNumber-" (booqlyapp-83777).\n\n'
          'Copy the Web client (auto created by Google Service) from Credentials, '
          'update config.env, run .\\scripts\\sync-google-oauth.ps1, then hot restart.';
    }
    return null;
  }
}
