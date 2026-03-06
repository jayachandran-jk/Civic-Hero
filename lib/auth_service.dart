import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? user;
  bool isLoading = false;

  String? currentDepartment; // store logged-in admin’s department

  // ---------------- LOGIN ----------------
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();

      debugPrint('🔐 Admin: Attempting to sign in with email: $email');

      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        debugPrint('❌ Firebase not initialized');
        throw Exception('Firebase not initialized. Please restart the app.');
      }

      UserCredential result =
          await _auth.signInWithEmailAndPassword(email: email, password: password);
      user = result.user;

      debugPrint('✅ Admin: Authentication successful for: ${user?.email}');

      final doc = await _firestore.collection('adminusers').doc(user!.uid).get();
      if (!doc.exists) {
        debugPrint('❌ Admin: User document not found in adminusers collection');
        await _auth.signOut();
        user = null;
        isLoading = false;
        notifyListeners();
        return false;
      }

      final data = doc.data()!;
      currentDepartment = data['department'] ?? '';

      debugPrint('✅ Admin: Department assigned: $currentDepartment');

      await user?.updateDisplayName(currentDepartment);
      await user?.reload();
      user = _auth.currentUser;

      await _firestore.collection('adminusers').doc(user!.uid).update({
        'last_login': FieldValue.serverTimestamp(),
      });

      isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      isLoading = false;
      notifyListeners();
      debugPrint("❌ Admin Login Error (${e.code}): ${e.message}");
      return false;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      debugPrint("❌ Admin Login Error: $e");
      return false;
    }
  }

  // ---------------- SIGN UP ----------------
  Future<String?> signUp(String email, String password, String department) async {
    try {
      isLoading = true;
      notifyListeners();

      if (password.length < 6) return "Password must be at least 6 characters";

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = result.user;
      if (user == null) return "User creation failed";

      currentDepartment = department;

      await user!.updateDisplayName(department);
      await user!.reload();
      user = _auth.currentUser;

      await _firestore.collection('adminusers').doc(user!.uid).set({
        'email': email,
        'department': department,
        'created_at': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
      });

      isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      isLoading = false;
      notifyListeners();
      return e.message;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return "Sign Up failed: $e";
    }
  }

  // ---------------- SIGN OUT ----------------
  Future<void> signOut() async {
    await _auth.signOut();
    user = null;
    currentDepartment = null;
    notifyListeners();
  }
}
