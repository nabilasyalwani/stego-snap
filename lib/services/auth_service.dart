import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:stego_snap/services/notification_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _notify({required String title, required String body}) async {
    try {
      await NotificationService.createNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
      );
    } catch (_) {}
  }

  Future<void> _upsertUserDocument(
    User user, {
    String? displayName,
    String? idStegoSnap,
    String? profileImageUrl,
    bool isNewUser = false,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);

    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': displayName ?? user.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (isNewUser) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['idStegoSnap'] = '';
      data['profileImage'] = '';
    }

    if (idStegoSnap != null) {
      data['idStegoSnap'] = idStegoSnap.trim();
    }

    if (profileImageUrl != null) {
      data['profileImage'] = profileImageUrl.trim();
    }

    await userRef.set(data, SetOptions(merge: true));
  }

  Future<bool> _isStegoIdAvailable(
    String idStegoSnap,
    String currentUid,
  ) async {
    final normalized = idStegoSnap.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final query = await _firestore
        .collection('users')
        .where('idStegoSnap', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return true;
    }

    return query.docs.first.id == currentUid;
  }

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        try {
          await _upsertUserDocument(result.user!);
        } on MissingPluginException catch (e) {
          await _notify(
            title: 'Login Warning',
            body: 'Firestore plugin is not connected yet: $e',
          );
        } on FirebaseException catch (e) {
          await _notify(
            title: 'Login Warning',
            body: 'Firestore sync failed on sign-in: ${e.message}',
          );
        } catch (e) {
          await _notify(
            title: 'Login Warning',
            body: 'Unexpected Firestore sync error on sign-in: $e',
          );
        }
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      await _notify(
        title: 'Login Failed',
        body: e.message ?? 'Authentication failed. Please try again.',
      );
      return null;
    } on FirebaseException catch (e) {
      await _notify(
        title: 'Login Failed',
        body: e.message ?? 'Firebase error occurred during login.',
      );
      return null;
    } catch (e) {
      await _notify(title: 'Login Failed', body: e.toString());
      return null;
    }
  }

  Future<User?> registerWithEmailAndPassword(
    String fullName,
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        await user.updateDisplayName(fullName);
        await user.reload();
        user = _firebaseAuth.currentUser;
        if (user != null) {
          try {
            await _upsertUserDocument(
              user,
              displayName: fullName,
              isNewUser: true,
            );
          } on MissingPluginException catch (e) {
            await _notify(
              title: 'Sign Up Warning',
              body: 'Firestore plugin is not connected yet: $e',
            );
          } on FirebaseException catch (e) {
            await _notify(
              title: 'Sign Up Warning',
              body: 'Firestore sync failed on sign-up: ${e.message}',
            );
          } catch (e) {
            await _notify(
              title: 'Sign Up Warning',
              body: 'Unexpected Firestore sync error on sign-up: $e',
            );
          }
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      await _notify(
        title: 'Sign Up Failed',
        body: e.message ?? 'Registration failed. Please try again.',
      );
      return null;
    } on FirebaseException catch (e) {
      await _notify(
        title: 'Sign Up Failed',
        body: e.message ?? 'Firebase error occurred during sign up.',
      );
      return null;
    } catch (e) {
      await _notify(title: 'Sign Up Failed', body: e.toString());
      return null;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        await _notify(
          title: 'Change Password Failed',
          body: 'No user is signed in.',
        );
        return false;
      }

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

      await _notify(
        title: 'Password Updated',
        body: 'Password updated successfully.',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        await _notify(
          title: 'Change Password Failed',
          body: 'The current password you entered is incorrect.',
        );
      } else {
        await _notify(
          title: 'Change Password Failed',
          body: 'An error occurred. Please try again.',
        );
      }
      return false;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<bool> updateUserProfile({
    required String displayName,
    required String idStegoSnap,
    String? profileImageUrl,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        await _notify(
          title: 'Update Profile Failed',
          body: 'No user is signed in.',
        );
        return false;
      }

      final normalizedName = displayName.trim();
      final normalizedStegoId = idStegoSnap.trim();
      final normalizedProfileImage = profileImageUrl?.trim() ?? '';

      if (normalizedName.isEmpty || normalizedStegoId.isEmpty) {
        await _notify(
          title: 'Update Profile Failed',
          body:
              'Display name dan idStegoSnap must be provided and cannot be empty.',
        );
        return false;
      }

      final isAvailable = await _isStegoIdAvailable(
        normalizedStegoId,
        user.uid,
      );
      if (!isAvailable) {
        await _notify(
          title: 'Update Profile Failed',
          body:
              'idStegoSnap has already been taken by another user. Please choose a different one.',
        );
        return false;
      }

      await user.updateDisplayName(normalizedName);
      await user.reload();

      final latestUser = _firebaseAuth.currentUser ?? user;
      await _upsertUserDocument(
        latestUser,
        displayName: normalizedName,
        idStegoSnap: normalizedStegoId,
        profileImageUrl: normalizedProfileImage,
      );

      await _notify(
        title: 'Profile Updated',
        body: 'Profile updated successfully.',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      await _notify(
        title: 'Update Profile Failed',
        body: e.message ?? 'Failed to update profile.',
      );
      return false;
    } on FirebaseException catch (e) {
      await _notify(
        title: 'Update Profile Failed',
        body: e.message ?? 'Failed to update Firestore profile.',
      );
      return false;
    } catch (e) {
      await _notify(
        title: 'Update Profile Failed',
        body: 'Unexpected error while updating profile.',
      );
      return false;
    }
  }
}
