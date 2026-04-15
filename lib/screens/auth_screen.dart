import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '', name = '';
  bool isLogin = true;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = context.read<FirebaseService>();

    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Registrieren')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Fit Buddy",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(height: 40),
                if (!isLogin)
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                    onChanged: (val) => setState(() => name = val),
                  ),
                if (!isLogin) const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  onChanged: (val) => setState(() => email = val),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Passwort', border: OutlineInputBorder()),
                  obscureText: true,
                  onChanged: (val) => setState(() => password = val),
                ),
                const SizedBox(height: 24),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isLogin ? 'Anmelden' : 'Konto erstellen'),
                    onPressed: () async {
                      setState(() => isLoading = true);
                      if (isLogin) {
                        await authService.signIn(email, password);
                      } else {
                        await authService.signUp(email, password, name);
                      }
                      if (mounted) setState(() => isLoading = false);
                    },
                  ),
                const SizedBox(height: 12),
                TextButton(
                  child: Text(isLogin ? 'Noch kein Konto? Registrieren' : 'Bereits ein Konto? Login'),
                  onPressed: () => setState(() => isLogin = !isLogin),
                ),
                const Divider(height: 40),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline),
                  label: const Text("Als Gast fortfahren"),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () async {
                    setState(() => isLoading = true);
                    await authService.signInAnonymously();
                    if (mounted) setState(() => isLoading = false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
