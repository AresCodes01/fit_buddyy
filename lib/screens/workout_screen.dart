import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _typeController = TextEditingController();
  
  // Timer State
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;
  bool _isLogging = false;

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = 0;
      _isRunning = false;
    });
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  void _logWorkout() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final db = context.read<FirebaseService>();
    final type = _typeController.text.trim();
    final durationText = _formatTime(_seconds);

    if (user != null && type.isNotEmpty && _seconds > 0) {
      setState(() => _isLogging = true);
      try {
        await db.logWorkout(user, type, durationText);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout erfolgreich geteilt! 🔥')),
          );
          _typeController.clear();
          _resetTimer();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      } finally {
        if (mounted) setState(() => _isLogging = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final db = context.read<FirebaseService>();

    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Timer')),
      body: Column(
        children: [
          _buildTimerCard(),
          const Divider(),
          Expanded(child: _buildWorkoutHistory(db, user.id)),
        ],
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _typeController,
            decoration: const InputDecoration(
              labelText: "Was trainierst du?",
              hintText: "z.B. Laufen, Yoga, Kraftsport",
              prefixIcon: Icon(Icons.fitness_center),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _formatTime(_seconds),
            style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _resetTimer,
                icon: const Icon(Icons.refresh),
                padding: const EdgeInsets.all(16),
              ),
              const SizedBox(width: 20),
              FloatingActionButton.large(
                onPressed: _toggleTimer,
                backgroundColor: _isRunning ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 20),
              IconButton.filledTonal(
                onPressed: _seconds > 0 ? _logWorkout : null,
                icon: const Icon(Icons.check),
                padding: const EdgeInsets.all(16),
              ),
            ],
          ),
          if (_isLogging)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkoutHistory(FirebaseService db, String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.getWorkouts(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final workouts = snapshot.data!;
        
        if (workouts.isEmpty) {
          return const Center(child: Text("Hier erscheint deine Historie."));
        }

        return ListView.builder(
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final workout = workouts[index];
            final date = (workout['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            return ListTile(
              leading: const Icon(Icons.history, color: Colors.blueAccent),
              title: Text(workout['type'] ?? 'Workout'),
              subtitle: Text(workout['duration'] ?? '00:00'),
              trailing: Text(DateFormat('dd.MM.').format(date)),
            );
          },
        );
      },
    );
  }
}
