import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/step_tracker_service.dart';

class Dashboard extends StatefulWidget {
  final UserModel user;
  const Dashboard({super.key, required this.user});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final StepTrackerService _stepService = StepTrackerService();
  final FirebaseService _db = FirebaseService();
  int _currentSteps = 0;

  @override
  void initState() {
    super.initState();
    _currentSteps = widget.user.dailySteps;
    _initSteps();
  }

  void _initSteps() async {
    bool granted = await _stepService.requestPermission();
    if (granted) {
      _stepService.initStepTracking((steps) {
        setState(() {
          _currentSteps = steps;
        });
        _db.updateSteps(widget.user.id, steps);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_walk, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text('Schritte heute', style: Theme.of(context).textTheme.headlineSmall),
            Text('$_currentSteps', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange),
                Text(' Streak: ${widget.user.streak} Tage', style: const TextStyle(fontSize: 20)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
