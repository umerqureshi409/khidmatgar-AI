import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/session_store.dart';
import '../services/booking_store.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String role; // 'CUSTOMER', 'PROVIDER', 'UNASSIGNED'

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    this.role = 'UNASSIGNED',
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'role': role,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    uid: j['uid'] ?? '',
    displayName: j['displayName'] ?? '',
    email: j['email'] ?? '',
    photoUrl: j['photoUrl'] ?? '',
    role: j['role'] ?? 'UNASSIGNED',
  );
}

class AuthNotifier extends StateNotifier<UserProfile?> {
  AuthNotifier() : super(null) {
    _init();
  }

  FirebaseAuth? get _auth {
    try { return FirebaseAuth.instance; } catch (_) { return null; }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _init() async {
    // 1. Try to restore session from local storage first (instant, no network)
    final saved = await SessionStore.instance.loadUser();
    if (saved != null) {
      state = UserProfile.fromJson(saved);
    }

    // 2. Load bookings
    await BookingStore.instance.load();

    // 3. Listen for Firebase auth changes (reconcile if Firebase re-validates)
    final auth = _auth;
    if (auth != null) {
      try {
        auth.authStateChanges().listen((User? user) async {
          if (user != null) {
            final profile = UserProfile(
              uid: user.uid,
              displayName: user.displayName ?? state?.displayName ?? 'Unknown User',
              email: user.email ?? state?.email ?? '',
              photoUrl: user.photoURL ??
                  'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.displayName ?? 'User')}&background=0D8ABC&color=fff&size=128',
              role: state?.role ?? 'UNASSIGNED',
            );
            state = profile;
            await SessionStore.instance.saveUser(profile.toJson());
          }
          // Don't clear state on null — keep local session until explicit logout
        });
      } catch (_) {}
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final auth = _auth;
      if (auth != null) {
        try {
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await auth.signInWithCredential(credential);
          return true;
        } catch (_) {}
      }

      // Firebase not configured — use real Google account
      final profile = UserProfile(
        uid: googleUser.id,
        displayName: googleUser.displayName ?? 'Google User',
        email: googleUser.email,
        photoUrl: googleUser.photoUrl ??
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(googleUser.displayName ?? 'User')}&background=0D8ABC&color=fff&size=128',
        role: 'UNASSIGNED',
      );
      state = profile;
      await SessionStore.instance.saveUser(profile.toJson());
      return true;
    } catch (_) {
      // Fallback demo user
      final profile = UserProfile(
        uid: 'mock_uid',
        displayName: 'Demo User',
        email: 'demo@khidmatgar.ai',
        photoUrl: 'https://ui-avatars.com/api/?name=Demo+User&background=0D8ABC&color=fff&size=128',
        role: 'UNASSIGNED',
      );
      state = profile;
      await SessionStore.instance.saveUser(profile.toJson());
      return true;
    }
  }

  void setRole(String role) {
    if (state != null) {
      final updated = UserProfile(
        uid: state!.uid,
        displayName: state!.displayName,
        email: state!.email,
        photoUrl: state!.photoUrl,
        role: role,
      );
      state = updated;
      SessionStore.instance.saveUser(updated.toJson());
    }
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _auth?.signOut();
    } catch (_) {}
    state = null;
    await SessionStore.instance.clearUser();
    await BookingStore.instance.clear();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserProfile?>((ref) {
  return AuthNotifier();
});