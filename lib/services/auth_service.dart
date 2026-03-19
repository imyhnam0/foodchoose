import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get userId => _auth.currentUser?.uid;

  Future<User> signInAnonymously() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    final result = await _auth.signInAnonymously();
    return result.user!;
  }
}
