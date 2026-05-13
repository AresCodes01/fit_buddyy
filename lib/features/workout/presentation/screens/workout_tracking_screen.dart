import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/workout/domain/models/workout_session.dart';
import 'package:fit_buddyy/features/workout/domain/repositories/workout_repository.dart';
import 'package:fit_buddyy/features/workout/presentation/widgets/workout_selection_grid.dart';

class WorkoutTrackingScreen extends StatelessWidget {
  const WorkoutTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<UserModel?, UserModel?>((user) => user);
    
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout erfassen'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Was hast du heute trainiert?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Wähle eine Aktivität aus und gib die Details manuell ein.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const WorkoutSelectionGrid(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(
                    'Deine letzten Workouts',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<List<WorkoutSession>>(
            stream: context.read<WorkoutRepository>().getWorkouts(user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final workouts = snapshot.data ?? [];
              
              if (workouts.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Noch keine Workouts erfasst.'),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final session = workouts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Text(session.type.icon, style: const TextStyle(fontSize: 20)),
                          ),
                          title: Text(
                            session.type == WorkoutType.other && session.customName != null
                                ? session.customName!
                                : session.type.label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${session.duration.inMinutes} min • ${session.intensity} • ${session.calories} kcal',
                          ),
                          trailing: Text(
                            DateFormat('dd.MM.').format(session.timestamp),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: workouts.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
