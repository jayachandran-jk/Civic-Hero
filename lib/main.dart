import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'data_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDGO_1c2xhgPi0-m0RU_OK9oN-pxRTPSN8",
        authDomain: "civicissue-aae6d.firebaseapp.com",
        projectId: "civicissue-aae6d",
        storageBucket: "civicissue-aae6d.firebasestorage.app",
        messagingSenderId: "559012084553",
        appId: "1:559012084553:web:371c1340ab7d25dc25f898",
        // Note: databaseURL removed as app uses Firestore, not Realtime Database
      ),
    );
    print('✅ Firebase initialized successfully (Admin App) - Project: civicissue-aae6d');
  } catch (e) {
    print('❌ Firebase initialization failed (Admin App): $e');
    // Continue anyway - error will show in UI
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<DataService>(create: (_) => DataService()),
      ],
      child: MaterialApp(
        title: 'CivicHero Admin',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/dashboard': (context) =>  DashboardScreen(),
        },
      ),
    );
  }
}
