import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fit_buddyy/features/workout/domain/models/workout_session.dart';
import 'package:fit_buddyy/features/workout/presentation/providers/workout_provider.dart';
import 'manual_workout_input_sheet.dart';

class WorkoutSelectionGrid extends StatelessWidget {
  const WorkoutSelectionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final type = WorkoutType.values[index];
            return WorkoutTypeCard(type: type);
          },
          childCount: WorkoutType.values.length,
        ),
      ),
    );
  }
}

class WorkoutTypeCard extends StatelessWidget {
  final WorkoutType type;

  const WorkoutTypeCard({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showInputSheet(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              type.icon,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 12),
            Text(
              type.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInputSheet(BuildContext context) {
    context.read<WorkoutProvider>().selectType(type);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent, // Ermöglicht abgerundete Ecken des Sheets
      builder: (context) => const ManualWorkoutInputSheet(),
    );
  }
}
