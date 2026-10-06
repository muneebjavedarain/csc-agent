import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool busy = false;
  String? error;

  Future<void> _signIn() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      if (e.code != 'popup-closed-by-user' &&
          e.code != 'cancelled-popup-request') {
        error = '${e.code}: ${e.message}';
      }
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, size: 48),
                  const SizedBox(height: 12),
                  const Text('CSC Professors Dashboard',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Aage barhne ke liye login karein',
                      style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy ? null : _signIn,
                    icon: const Icon(Icons.login),
                    label: Text(busy ? 'Wait...' : 'Google se login karein'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    SelectableText(error!,
                        style:
                        const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}