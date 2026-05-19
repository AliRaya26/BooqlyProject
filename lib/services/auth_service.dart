import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthResult {
  final User? user;
  final String? errorMessage;

  const AuthResult({this.user, this.errorMessage});

  bool get isSuccess => user != null;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PreferencesService _preferencesService = PreferencesService();

  String _mapError(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'email-already-in-use' =>
          'This email is already registered. Try signing in.',
        'weak-password' => 'Password must be at least 6 characters.',
        'invalid-email' => 'Please enter a valid email address.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'Invalid email or password.',
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
        // Auth succeeded; onboarding can still save preferences later.
      }

      return AuthResult(user: user);
    } catch (e) {
      debugPrint('AuthService.signUp: $e');
      return AuthResult(errorMessage: _mapError(e));
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult(user: result.user);
    } catch (e) {
      debugPrint('AuthService.signIn: $e');
      return AuthResult(errorMessage: _mapError(e));
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint('AuthService.signOut Google: $e');
    }
    await _auth.signOut();
  }

  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // 🔴 FORCE logout from previous session
      await googleSignIn.signOut();
      await _auth.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return const AuthResult(errorMessage: 'Google sign-in cancelled.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user == null) {
        return const AuthResult(errorMessage: 'Google sign-in failed.');
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        await _createUserDocument(
          uid: user.uid,
          email: user.email ?? '',
          firstName: user.displayName?.split(' ').first ?? 'User',
          lastName: '',
        );
      }

      return AuthResult(user: user);
    } catch (e) {
      return AuthResult(errorMessage: _mapError(e));
    }
  }
}
