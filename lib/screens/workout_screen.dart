import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _typeController = TextEditingController();
  final _durationController = TextEditingController();

  void _logWorkout() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final db = context.read<FirebaseService>();

    if (user != null && _typeController.text.isNotEmpty && _durationController.text.isNotEmpty) {
      await db.logWorkout(user.id, _typeController.text, _durationController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout gespeichert!')));
        _typeController.clear();
        _durationController.clear();
      }
    }
  }

  @override
  void dispose() {
    _typeController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _typeController, 
              decoration: const InputDecoration(labelText: 'Workout Typ (z.B. Laufen)')
            ),
            TextField(
              controller: _durationController, 
              decoration: const InputDecoration(labelText: 'Dauer (z.B. 30 Min)')
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _logWorkout, 
              child: const Text('Workout loggen')
            ),
          ],
        ),
      ),
    );
  }
}
