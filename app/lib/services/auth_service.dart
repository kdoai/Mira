/// Firebase Auth service (Google Sign-In).
/// Ref: PLAN.md Section 0.1 Rule 5 (Auth Required), Section 3.1
///
/// Uses Firebase Auth + Google Sign-In.
/// All backend calls require the Firebase ID token.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Current Firebase user (null if not signed in)
  User? get currentUser => _auth.currentUser;

  /// Whether user is signed in
  bool get isSignedIn => currentUser != null;

  /// Stream of auth state changes (fires on sign-in/out only)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current Firebase ID token for backend API calls.
  /// Ref: PLAN.md Section 0.1 Rule 5
  Future<String?> getIdToken() async {
    final user = currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Sign in with Google.
  /// Ref: PLAN.md Section 3.1 (Google Sign-In)
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
