import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/step_tracker_service.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final StepTrackerService _stepService = StepTrackerService();
  int _currentSteps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSteps();
    });
  }

  void _initSteps() async {
    if (!mounted) return;
    final userModel = Provider.of<UserModel?>(context, listen: false);
    if (userModel == null) return;
    
    setState(() {
      _currentSteps = userModel.dailySteps;
    });
    
    bool granted = await _stepService.requestPermission();
    if (granted && mounted) {
      _stepService.initStepTracking((steps) {
        if (mounted) {
          setState(() {
            _currentSteps = steps;
          });
          context.read<FirebaseService>().updateSteps(userModel.id, steps);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    
    if (user == null) return const Center(child: CircularProgressIndicator());

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
                Text(' Streak: ${user.streak} Tage', style: const TextStyle(fontSize: 20)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
