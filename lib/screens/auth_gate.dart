import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

/// Login nahi to login screen, galat email ho to rok do, theek ho to dashboard.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();

        final email = (user.email ?? '').toLowerCase();
        final allowed = allowedEmails.map((e) => e.toLowerCase()).toList();
        if (!allowed.contains(email)) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('$email ko is app ki ijazat nahi hai'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Dusre account se login karein'),
                  ),
                ],
              ),
            ),
          );
        }
        return const DashboardScreen();
      },
    );
  }
}