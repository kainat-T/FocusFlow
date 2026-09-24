import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── current user stream ───────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── current user ─────────────────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;

  // ── register ──────────────────────────────────────────────────────────────
  /// Creates a Firebase Auth account and stores a user document in Firestore.
  /// Returns null on success, or a human-readable error string on failure.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name — fire-and-forget, don't await
      credential.user?.updateDisplayName(name.trim()).catchError((_) {});

      return null; // success — AuthGate handles navigation
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (e) {
      return 'Unexpected error: ${e.toString()}';
    }
  }

  // ── login ─────────────────────────────────────────────────────────────────
  /// Returns null on success, or a human-readable error string on failure.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (e) {
      return 'Unexpected error: ${e.toString()}';
    }
  }

  // ── logout ────────────────────────────────────────────────────────────────
  Future<void> logout() => _auth.signOut();

  // ── delete account ────────────────────────────────────────────────────────
  /// Re-authenticates with the given password then permanently deletes
  /// the Firebase Auth account.
  /// Returns null on success, or a human-readable error string on failure.
  Future<String?> deleteAccount({required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No signed-in user found.';

      // Re-authenticate first to satisfy Firebase's recent-login requirement
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Now delete
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (e) {
      return 'Unexpected error: ${e.toString()}';
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Please contact support.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Error ($code). Please try again.';
    }
  }
}
