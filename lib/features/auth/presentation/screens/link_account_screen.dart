import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/auth_repository.dart';

class LinkAccountScreen extends StatefulWidget {
  const LinkAccountScreen({super.key});

  @override
  State<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends State<LinkAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '', name = '', password = '';
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authRepository = context.read<AuthRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Konto sichern')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Sichere deinen Fortschritt",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Gib deine Daten ein, um deinen Gast-Account in ein festes Konto umzuwandeln. Alle deine Schritte und Workouts bleiben erhalten!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Anzeigename', border: OutlineInputBorder()),
                onChanged: (val) => setState(() => name = val),
                validator: (val) => val!.isEmpty ? 'Name eingeben' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                onChanged: (val) => setState(() => email = val),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val!.isEmpty ? 'Email eingeben' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Passwort', border: OutlineInputBorder()),
                obscureText: true,
                onChanged: (val) => setState(() => password = val),
                validator: (val) => val!.length < 6 ? 'Min. 6 Zeichen' : null,
              ),
              const SizedBox(height: 30),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Konto jetzt sichern'),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => isLoading = true);
                      try {
                        await authRepository.linkAnonymousAccount(email, password, name);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Konto erfolgreich verknüpft!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
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
            ],
          ),
        ),
      ),
    );
  }
}
