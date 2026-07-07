import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<void> syncOrCreateUser(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    final String nameToSave = user.displayName ?? (user.isAnonymous ? 'Fit-Entdecker' : 'User');

    if (!docSnap.exists) {
      await docRef.set({
        'email': user.email ?? '',
        'displayName': nameToSave,
        'photoUrl': user.photoURL ?? '',
        'level': 1,
        'points': 0,
        'dailySteps': 0,
        'weeklySteps': 0,
        'streak': 0,
        'groupIds': [],
        'isAnonymous': user.isAnonymous,
        'workoutGoalWeekly': 3,
        'workoutsThisWeek': 0,
        'goalValue': 10000,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // WICHTIG: Wenn der Name in Firebase Authentication vorhanden ist, aber in Firestore noch auf "User" steht, aktualisieren
      final existingData = docSnap.data();
      if (existingData != null && 
          (existingData['displayName'] == 'User' || existingData['displayName'] == '') && 
          user.displayName != null && 
          user.displayName!.isNotEmpty) {
        await docRef.update({'displayName': user.displayName});
      }
    }
  }

  @override
  Stream<UserModel?> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) return UserModel.fromMap(snap.data()!, snap.id);
      return null;
    });
  }

  @override
  Future<UserCredential?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      if (result.user != null) await syncOrCreateUser(result.user!);
      return result;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (result.user != null) {
        // Erst den Namen im Auth-Profil setzen
        await result.user!.updateDisplayName(name);
        // Das User-Objekt neu laden, damit der Name sicher im Objekt ist
        await result.user!.reload();
        final updatedUser = _auth.currentUser;
        if (updatedUser != null) {
          await syncOrCreateUser(updatedUser);
        }
      }
      return result;
    } catch (e) {
      rethrow; // Fehler weitergeben für UI-Feedback
    }
  }

  @override
  Future<UserCredential?> signIn(String email, String password) => 
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> updateProfilePicture(String uid, String url) async {
    await _db.collection('users').doc(uid).update({'photoUrl': url});
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.verifyBeforeUpdateEmail(newEmail);
      await _db.collection('users').doc(user.uid).update({'email': newEmail});
    }
  }

  @override
  Future<void> updateDisplayName(String uid, String newName) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(newName);
      await _db.collection('users').doc(uid).update({'displayName': newName});
    }
  }

  @override
  Future<void> linkAnonymousAccount(String email, String password, String name) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) return;

    AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
    UserCredential userCredential = await user.linkWithCredential(credential);
    
    if (userCredential.user != null) {
      await userCredential.user!.updateDisplayName(name);
      await _db.collection('users').doc(userCredential.user!.uid).update({
        'email': email,
        'displayName': name,
        'isAnonymous': false,
      });
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
