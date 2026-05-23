import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:booqly/services/email_service.dart';
import 'package:booqly/services/google_oauth_config.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthResult {
  final User? user;
  final String? errorMessage;
  final bool isNewUser;

  const AuthResult({
    this.user,
    this.errorMessage,
    this.isNewUser = false,
  });

  bool get isSuccess => user != null;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PreferencesService _preferencesService = PreferencesService();

  GoogleSignIn? _googleSignIn;

  static final _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  bool isValidEmailFormat(String email) => _emailPattern.hasMatch(email);

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String? get _webClientId => GoogleOAuthConfig.webClientId;

  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
      // Web: clientId. Android/iOS: serverClientId (Firebase Web client ID).
      clientId: kIsWeb ? _webClientId : null,
      serverClientId: kIsWeb ? null : _webClientId,
    );
    return _googleSignIn!;
  }

  /// Web login uses Firebase [signInWithPopup] (no custom OAuth client required).
  /// [GOOGLE_WEB_CLIENT_ID] is still used for Calendar linking on web.
  bool get hasGoogleWebConfig => kIsWeb || (_webClientId != null);

  /// Returns registered state, or `null` when Firestore could not be reached.
  Future<bool?> emailIsRegistered(String email) async {
    try {
      final doc = await _firestore
          .collection('email_index')
          .doc(_normalizeEmail(email))
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 12));
      return doc.exists;
    } catch (e) {
      debugPrint('AuthService.emailIsRegistered: $e');
      return null;
    }
  }

  ({String firstName, String lastName}) _splitName(String? displayName) {
    final trimmed = displayName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return (firstName: 'User', lastName: '');
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    return (
      firstName: parts.first,
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
    );
  }

  String? _googleWebOriginHint() {
    if (!kIsWeb) return null;
    final origin = Uri.base.origin;
    if (origin.isEmpty) return null;
    return origin;
  }

  String _mapGoogleSignInError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('access_denied') ||
        text.contains('org_internal') ||
        text.contains('invalid_client_id') ||
        (text.contains('403') && text.contains('access'))) {
      return 'This Google account is not allowed to sign in yet.\n\n'
          'Your Google Cloud OAuth app is probably in **Testing** mode, which '
          'only permits accounts listed as test users.\n\n'
          'Fix (project booqlyapp-83777): open Google Cloud Console → '
          'APIs & Services → OAuth consent screen → either add this Gmail under '
          'Test users, or publish the app to **Production** so any Google '
          'account can sign in.\n\n'
          'Details: firebase/GOOGLE_SIGNIN_SETUP.md';
    }
    if (text.contains('invalid_client') ||
        text.contains('no registered origin') ||
        text.contains('origin_mismatch')) {
      final origin = _googleWebOriginHint();
      return 'Google sign-in blocked by OAuth settings.\n\n'
          '1. Firebase Console → Authentication → Sign-in method → enable Google.\n'
          '2. Authentication → Settings → Authorized domains → ensure localhost is listed.\n'
          '${origin != null ? '3. If you still see this, add $origin to Google Cloud OAuth Web client origins (firebase/GOOGLE_CALENDAR_SETUP.md).\n' : ''}'
          '\nThen hot restart the app (R) and try again.';
    }
    if (text.contains('popup') && text.contains('block')) {
      return 'Google sign-in popup was blocked. Allow popups for localhost in your browser.';
    }
    if (text.contains('apiexception: 10') ||
        text.contains('developer_error') ||
        text.contains('sign_in_failed')) {
      return 'Google sign-in: SHA-1 mismatch for this debug build.\n\n'
          'Firebase → Project settings → Android (com.example.booqly) → '
          'add SHA-1:\n'
          'F9:1B:F9:D5:DF:E7:1D:9F:CE:83:C9:C0:43:C7:CB:17:65:F0:F4:9E\n\n'
          'Enable Google sign-in, download google-services.json '
          '(certificate_hash must be f91bf9d5…f49e), replace android/app/, '
          'then flutter clean && flutter run.\n'
          'Details: firebase/GOOGLE_SIGNIN_SETUP.md';
    }
    if (text.contains('network') || text.contains('socket')) {
      return 'Network error during Google sign-in. Check Wi‑Fi and try again.';
    }
    return _mapError(e);
  }

  String _mapError(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'email-already-in-use' =>
          'This email is already registered. Try signing in.',
        'weak-password' => 'Password must be at least 6 characters.',
        'invalid-email' => 'Please enter a valid email address.',
        'user-not-found' => 'Wrong email',
        'wrong-password' => 'Wrong password',
        'invalid-credential' => 'Wrong email or password.',
        'account-exists-with-different-credential' =>
          'This email uses password sign-in. Log in with email and password.',
        'popup-closed-by-user' => 'Google sign-in cancelled.',
        'too-many-requests' =>
          'Too many attempts. Wait a few minutes and try again.',
        _ => e.message ?? 'Authentication failed.',
      };
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Firestore blocked the save. Publish firestore.rules in Firebase Console (see firebase/FIRESTORE_SETUP.md).';
      }
      return e.message ?? 'Database error: ${e.code}';
    }
    return e.toString();
  }

  /// Firestore rules allow create but not update on [email_index].
  Future<void> _ensureEmailIndexed(String email) async {
    final ref =
        _firestore.collection('email_index').doc(_normalizeEmail(email));
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (email.isNotEmpty) {
      await _ensureEmailIndexed(email);
    }

    await _preferencesService.createEmptyPreferences(uid);
  }

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) {
        return const AuthResult(errorMessage: 'Account could not be created.');
      }

      try {
        await user.updateDisplayName('$firstName $lastName');
      } catch (e) {
        debugPrint('Display name update skipped: $e');
      }

      try {
        await _createUserDocument(
          uid: user.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
        );
      } catch (e) {
        debugPrint('AuthService.signUp profile write failed: $e');
      }

      return AuthResult(user: user, isNewUser: true);
    } catch (e) {
      debugPrint('AuthService.signUp: $e');
      return AuthResult(errorMessage: _mapError(e));
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (!isValidEmailFormat(trimmedEmail)) {
      return const AuthResult(errorMessage: 'Please enter a valid email address.');
    }

    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      return AuthResult(user: result.user);
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.signIn: $e');
      if (e.code == 'wrong-password') {
        return const AuthResult(errorMessage: 'Wrong password');
      }
      if (e.code == 'user-not-found') {
        return const AuthResult(errorMessage: 'Wrong email');
      }
      if (e.code == 'invalid-credential') {
        final registered = await emailIsRegistered(trimmedEmail);
        if (registered == null) {
          return const AuthResult(
            errorMessage:
                'Could not verify account (network). Check connection and try again.',
          );
        }
        return AuthResult(
          errorMessage: registered ? 'Wrong password' : 'Wrong email',
        );
      }
      return AuthResult(errorMessage: _mapError(e));
    } catch (e) {
      debugPrint('AuthService.signIn: $e');
      return AuthResult(errorMessage: _mapError(e));
    }
  }

  /// Sends password-reset email. Tries the `sendPasswordResetEmail` Cloud
  /// Function first (Gmail SMTP via nodemailer with our custom Booqly
  /// template), and falls back to Firebase Auth's built-in reset email when
  /// the function isn't reachable (`unavailable` / `internal` / network error
  /// / not deployed). Definitive errors from the function — `not-found`,
  /// `failed-precondition`, `invalid-argument` — are returned as-is so the
  /// caller can show a precise message instead of pretending an email was
  /// sent.
  Future<String?> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    if (!isValidEmailFormat(trimmedEmail)) {
      return 'Please enter a valid email address.';
    }

    final result = await EmailService().sendPasswordResetEmail(
      toEmail: trimmedEmail,
    );
    if (result.success) return null;

    // The Cloud Function gives a definitive answer for these codes. Falling
    // back to Firebase's built-in reset on `not-found` or `failed-precondition`
    // would silently succeed (email-enumeration protection) and trick the user
    // into thinking an email is on the way that will never arrive.
    final code = result.functionsErrorCode;
    final isDefinitive = code == 'not-found' ||
        code == 'failed-precondition' ||
        code == 'invalid-argument';
    if (isDefinitive) {
      return result.errorMessage ?? 'Could not send reset email.';
    }

    // Only fall back when the Cloud Function itself isn't reachable.
    final shouldFallback = code == null ||
        code == 'unavailable' ||
        code == 'internal' ||
        (result.errorMessage?.toLowerCase().contains('deploy') ?? false);
    if (!shouldFallback) {
      return result.errorMessage ?? 'Could not send reset email.';
    }

    debugPrint(
      'AuthService: Cloud Function unavailable, using Firebase reset email.',
    );
    try {
      await _auth.sendPasswordResetEmail(email: trimmedEmail);
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.sendPasswordResetEmail fallback: $e');
      return _mapError(e);
    } catch (e) {
      debugPrint('AuthService.sendPasswordResetEmail fallback: $e');
      return _mapError(e);
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await googleSignIn.signOut();
      } catch (e) {
        debugPrint('AuthService.signOut Google: $e');
      }
    }
    await _auth.signOut();
  }

  /// Google sign-in / sign-up. Web uses Firebase popup; mobile uses [google_sign_in].
  ///
  /// [forceAccountPicker] signs out of Google first so users can choose another
  /// account (useful on sign-up).
  Future<AuthResult> signInWithGoogle({bool forceAccountPicker = false}) async {
    try {
      if (kIsWeb) {
        final result = await _auth.signInWithPopup(GoogleAuthProvider());
        return _completeGoogleSignIn(
          result,
          displayName: result.user?.displayName,
          email: result.user?.email,
        );
      }

      if (_webClientId == null || _webClientId!.isEmpty) {
        return const AuthResult(
          errorMessage:
              'Google sign-in is not configured. Add GOOGLE_WEB_CLIENT_ID to '
              'assets/config.env (Firebase → Authentication → Google → Web client ID), '
              'then restart the app.',
        );
      }

      if (forceAccountPicker) {
        try {
          await googleSignIn.signOut();
        } catch (e) {
          debugPrint('AuthService.signInWithGoogle signOut: $e');
        }
      }

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResult(errorMessage: 'Google sign-in cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        return const AuthResult(
          errorMessage:
              'Google did not return an ID token. Check OAuth client setup.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      return _completeGoogleSignIn(
        result,
        displayName: googleUser.displayName ?? result.user?.displayName,
        email: googleUser.email,
      );
    } catch (e, st) {
      debugPrint('AuthService.signInWithGoogle: $e\n$st');
      return AuthResult(errorMessage: _mapGoogleSignInError(e));
    }
  }

  Future<AuthResult> _completeGoogleSignIn(
    UserCredential result, {
    String? displayName,
    String? email,
  }) async {
    final user = result.user;
    if (user == null) {
      return const AuthResult(errorMessage: 'Google sign-in failed.');
    }

    final firebaseNewUser = result.additionalUserInfo?.isNewUser ?? false;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final needsProfile = !doc.exists;
    final isNewUser = firebaseNewUser || needsProfile;

    if (needsProfile) {
      final name = _splitName(displayName ?? user.displayName);
      final resolvedEmail = email ?? user.email ?? '';

      try {
        await _createUserDocument(
          uid: user.uid,
          email: resolvedEmail,
          firstName: name.firstName,
          lastName: name.lastName,
        );
      } catch (e) {
        debugPrint('AuthService.signInWithGoogle profile write failed: $e');
        final message = _mapError(e);
        return AuthResult(user: user, isNewUser: true, errorMessage: message);
      }

      try {
        final fullName = [
          name.firstName,
          if (name.lastName.isNotEmpty) name.lastName,
        ].join(' ');
        if (fullName.isNotEmpty) {
          await user.updateDisplayName(fullName);
        }
      } catch (e) {
        debugPrint('Display name update skipped: $e');
      }
    }

    return AuthResult(user: user, isNewUser: isNewUser);
  }
}
