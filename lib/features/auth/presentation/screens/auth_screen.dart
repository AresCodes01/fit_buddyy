import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '', emailConfirm = '', password = '', passwordConfirm = '', name = '';
  bool isLogin = true;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authRepository = context.read<AuthRepository>();

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
                Text(
                  "Fit Buddy",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 40),
                if (!isLogin) ...[
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Anzeigename', border: OutlineInputBorder()),
                    onChanged: (val) => setState(() => name = val),
                    validator: (val) => val!.isEmpty ? 'Name eingeben' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  onChanged: (val) => setState(() => email = val),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val!.isEmpty ? 'Email eingeben' : null,
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Email wiederholen', border: OutlineInputBorder()),
                    onChanged: (val) => setState(() => emailConfirm = val),
                    validator: (val) => val != email ? 'Emails stimmen nicht überein' : null,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Passwort', border: OutlineInputBorder()),
                  obscureText: true,
                  onChanged: (val) => setState(() => password = val),
                  validator: (val) => val!.length < 6 ? 'Min. 6 Zeichen' : null,
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Passwort wiederholen', border: OutlineInputBorder()),
                    obscureText: true,
                    onChanged: (val) => setState(() => passwordConfirm = val),
                    validator: (val) => val != password ? 'Passwörter stimmen nicht überein' : null,
                  ),
                ],
                const SizedBox(height: 24),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isLogin ? 'Anmelden' : 'Konto erstellen'),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => isLoading = true);
                        try {
                          if (isLogin) {
                            await authRepository.signIn(email, password);
                          } else {
                            await authRepository.signUp(email, password, name);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fehler: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => isLoading = false);
                        }
                      }
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
                    try {
                      await authRepository.signInAnonymously();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Fehler: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => isLoading = false);
                    }
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
