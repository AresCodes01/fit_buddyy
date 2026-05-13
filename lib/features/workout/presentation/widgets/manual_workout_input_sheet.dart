import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/workout/domain/models/workout_session.dart';
import 'package:fit_buddyy/features/workout/presentation/providers/workout_provider.dart';

class ManualWorkoutInputSheet extends StatefulWidget {
  const ManualWorkoutInputSheet({super.key});

  @override
  State<ManualWorkoutInputSheet> createState() => _ManualWorkoutInputSheetState();
}

class _ManualWorkoutInputSheetState extends State<ManualWorkoutInputSheet> {
  final _durationController = TextEditingController(text: '30');
  final _customNameController = TextEditingController();
  String _intensity = 'Mittel';
  final List<String> _intensities = ['Leicht', 'Mittel', 'Intensiv', 'Maximum'];

  @override
  void dispose() {
    _durationController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

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
      child: SingleChildScrollView(
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
            if (type == WorkoutType.other) ...[
              Text(
                'Was hast du gemacht?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customNameController,
                decoration: InputDecoration(
                  hintText: "z.B. Fußball, Klettern...",
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'Dauer (Minuten)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixText: "Min",
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildQuickTimeButton(15),
                const SizedBox(width: 8),
                _buildQuickTimeButton(45),
                const SizedBox(width: 8),
                _buildQuickTimeButton(60),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Intensität',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: _intensities.map((i) => ButtonSegment(value: i, label: Text(i, style: const TextStyle(fontSize: 12)))).toList(),
                selected: {_intensity},
                onSelectionChanged: (newSelection) {
                  setState(() => _intensity = newSelection.first);
                },
              ),
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
      ),
    );
  }

  Widget _buildQuickTimeButton(int mins) {
    return InkWell(
      onTap: () => setState(() => _durationController.text = mins.toString()),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text("+$mins"),
      ),
    );
  }

  Future<void> _saveWorkout() async {
    final workoutProvider = context.read<WorkoutProvider>();
    final user = context.read<UserModel?>();
    final durationMins = int.tryParse(_durationController.text) ?? 0;
    
    if (user == null || durationMins <= 0) return;

    int baseCalories = (durationMins * 7); 
    if (_intensity == 'Leicht') baseCalories = (baseCalories * 0.7).toInt();
    if (_intensity == 'Intensiv') baseCalories = (baseCalories * 1.3).toInt();
    if (_intensity == 'Maximum') baseCalories = (baseCalories * 1.6).toInt();

    final success = await workoutProvider.saveWorkout(
      userId: user.id,
      userName: user.displayName,
      duration: Duration(minutes: durationMins),
      intensity: _intensity,
      calories: baseCalories,
      customName: _customNameController.text.isNotEmpty ? _customNameController.text : null,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout erfolgreich gespeichert!')),
        );
      }
    }
  }
}
