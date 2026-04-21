import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  bool _isLogging = false;

  void _logWorkout() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final db = context.read<FirebaseService>();

    if (user != null && _typeController.text.isNotEmpty && _durationController.text.isNotEmpty) {
      setState(() => _isLogging = true);
      try {
        await db.logWorkout(user, _typeController.text, _durationController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout gespeichert & Gruppe benachrichtigt! 🔥')),
          );
          _typeController.clear();
          _durationController.clear();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLogging = false);
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
    final user = Provider.of<UserModel?>(context);
    final db = context.read<FirebaseService>();

    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: Column(
        children: [
          _buildWorkoutForm(),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Deine Historie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          ),
          Expanded(
            child: _buildWorkoutHistory(db, user.id),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _typeController, 
            decoration: const InputDecoration(
              labelText: 'Was hast du gemacht? (z.B. Joggen)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fitness_center),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationController, 
            decoration: const InputDecoration(
              labelText: 'Dauer (z.B. 30 Min)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.timer),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isLogging ? null : _logWorkout, 
              child: _isLogging 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Workout loggen & teilen'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutHistory(FirebaseService db, String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.getWorkouts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final workouts = snapshot.data ?? [];
        
        if (workouts.isEmpty) {
          return const Center(
            child: Text('Noch keine Workouts geloggt.', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final workout = workouts[index];
            final timestamp = workout['timestamp'] != null 
                ? (workout['timestamp'] as dynamic).toDate() 
                : DateTime.now();
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.bolt, color: Colors.white),
                ),
                title: Text(workout['type'] ?? 'Unbekannt'),
                subtitle: Text(workout['duration'] ?? ''),
                trailing: Text(
                  DateFormat('dd.MM. HH:mm').format(timestamp),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
