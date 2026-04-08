import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseService _auth = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '', name = '';
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Registrieren')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (!isLogin)
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (val) => setState(() => name = val),
                ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: (val) => setState(() => email = val),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Passwort'),
                obscureText: true,
                onChanged: (val) => setState(() => password = val),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: Text(isLogin ? 'Anmelden' : 'Konto erstellen'),
                onPressed: () async {
                  if (isLogin) {
                    await _auth.signIn(email, password);
                  } else {
                    await _auth.signUp(email, password, name);
                  }
                },
              ),
              TextButton(
                child: Text(isLogin ? 'Noch kein Konto? Registrieren' : 'Bereits ein Konto? Login'),
                onPressed: () => setState(() => isLogin = !isLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
