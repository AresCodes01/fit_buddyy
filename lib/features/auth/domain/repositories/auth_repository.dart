import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<UserCredential?> signIn(String email, String password);
  Future<UserCredential?> signUp(String email, String password, String name);
  Future<UserCredential?> signInAnonymously();
  Future<void> signOut();
  Stream<UserModel?> getUserData(String uid);
  Future<void> syncOrCreateUser(User user);
  Future<void> updateProfilePicture(String uid, String url);
  Future<void> updateEmail(String newEmail);
  Future<void> updateDisplayName(String uid, String newName);
}
