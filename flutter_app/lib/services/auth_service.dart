import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn();
  bool isLoading = true;

  User? get user => _auth.currentUser;

  AuthService() {
    _auth.authStateChanges().listen((_) {
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return;
    final gAuth = await account.authentication;
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      ),
    );
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
