import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class WorkoutScreen extends StatefulWidget {
  final UserModel user;
  const WorkoutScreen({super.key, required this.user});

  @override
  _WorkoutScreenState createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final FirebaseService _db = FirebaseService();
  final _typeController = TextEditingController();
  final _durationController = TextEditingController();

  void _logWorkout() async {
    if (_typeController.text.isNotEmpty && _durationController.text.isNotEmpty) {
      await _db.logWorkout(widget.user.id, _typeController.text, _durationController.text);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout gespeichert!')));
      _typeController.clear();
      _durationController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Tracken')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _typeController, decoration: const InputDecoration(labelText: 'Workout Typ (z.B. Laufen)')),
            TextField(controller: _durationController, decoration: const InputDecoration(labelText: 'Dauer (z.B. 30 Min)')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _logWorkout, child: const Text('Workout loggen')),
          ],
        ),
      ),
    );
  }
}
