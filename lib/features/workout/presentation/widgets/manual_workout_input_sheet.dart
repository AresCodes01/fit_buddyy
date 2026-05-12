import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fit_buddyy/models/user_model.dart';
import 'package:fit_buddyy/features/workout/domain/models/workout_session.dart';
import 'package:fit_buddyy/features/workout/presentation/providers/workout_provider.dart';

class ManualWorkoutInputSheet extends StatefulWidget {
  const ManualWorkoutInputSheet({super.key});

  @override
  State<ManualWorkoutInputSheet> createState() => _ManualWorkoutInputSheetState();
}

class _ManualWorkoutInputSheetState extends State<ManualWorkoutInputSheet> {
  double _duration = 30;
  String _intensity = 'Mittel';
  final List<String> _intensities = ['Leicht', 'Mittel', 'Intensiv', 'Maximum'];

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<WorkoutProvider, bool>((p) => p.isLoading);
    final type = context.select<WorkoutProvider, WorkoutType?>((p) => p.selectedType);

    if (type == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${type.icon} ${type.label} erfassen',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Dauer: ${_duration.toInt()} Minuten',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _duration,
            min: 5,
            max: 180,
            divisions: 35,
            label: '${_duration.toInt()} min',
            onChanged: (value) => setState(() => _duration = value),
          ),
          const SizedBox(height: 16),
          Text(
            'Intensität',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: _intensities.map((i) => ButtonSegment(value: i, label: Text(i))).toList(),
            selected: {_intensity},
            onSelectionChanged: (newSelection) {
              setState(() => _intensity = newSelection.first);
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading ? null : _saveWorkout,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(isLoading ? 'Speichert...' : 'Workout speichern'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _saveWorkout() async {
    final workoutProvider = context.read<WorkoutProvider>();
    final user = context.read<UserModel?>();
    
    if (user == null) return;

    // Basic calorie calculation logic
    int baseCalories = (_duration * 7).toInt(); // ~7 cal/min for medium
    if (_intensity == 'Leicht') baseCalories = (baseCalories * 0.7).toInt();
    if (_intensity == 'Intensiv') baseCalories = (baseCalories * 1.3).toInt();
    if (_intensity == 'Maximum') baseCalories = (baseCalories * 1.6).toInt();

    final success = await workoutProvider.saveWorkout(
      userId: user.id,
      userName: user.displayName,
      duration: Duration(minutes: _duration.toInt()),
      intensity: _intensity,
      calories: baseCalories,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout erfolgreich gespeichert!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Speichern.')),
        );
      }
    }
  }
}
