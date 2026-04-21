import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/user_model.dart';
import '../models/daily_stats_model.dart';
import '../services/firebase_service.dart';
import '../services/step_tracker_service.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/common_widgets.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final StepTrackerService _stepService = StepTrackerService();
  int _todayLiveSteps = 0;

  @override
  void initState() {
    super.initState();
    _initLiveStepTracking();
  }

  void _initLiveStepTracking() async {
    final userModel = Provider.of<UserModel?>(context, listen: false);
    if (userModel == null) return;

    bool granted = await _stepService.requestPermission();
    if (granted && mounted) {
      _stepService.initStepTracking((steps) {
        if (mounted) {
          setState(() => _todayLiveSteps = steps);
          final todayId = DateTime.now().toString().split(' ')[0];
          context.read<FirebaseService>().updateSteps(userModel.id, todayId, steps);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final db = context.read<FirebaseService>();

    if (user == null) return const LoadingSpinner();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(user),
              const SizedBox(height: 20),
              _buildDateNavigation(context, dashboardProvider),
              const SizedBox(height: 20),
              _buildMainStepCard(dashboardProvider, db, user),
              const SizedBox(height: 25),
              const SectionTitle("Dein Status"),
              _buildStatsGrid(user),
              const SizedBox(height: 25),
              const SectionTitle("Wochen-Trend"),
              _buildWeeklyChart(db, user.id),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Moin,", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            Text(user.displayName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.star, color: Theme.of(context).colorScheme.primary, size: 18),
              const SizedBox(width: 4),
              Text("Lvl ${user.level}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateNavigation(BuildContext context, DashboardProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: provider.previousDay,
        ),
        Text(
          provider.formattedDate,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: provider.nextDay,
        ),
      ],
    );
  }

  Widget _buildMainStepCard(DashboardProvider provider, FirebaseService db, UserModel user) {
    return StreamBuilder<DailyStatsModel?>(
      stream: db.getDailyStats(user.id, provider.dateId),
      builder: (context, snapshot) {
        int steps = provider.isToday ? (_todayLiveSteps > 0 ? _todayLiveSteps : (snapshot.data?.steps ?? 0)) : (snapshot.data?.steps ?? 0);
        double progress = (steps / user.goalValue).clamp(0.0, 1.0);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.directions_walk, color: Colors.white, size: 28),
                  SizedBox(width: 10),
                  Text("Heutige Schritte", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 20),
              Text("$steps", style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.3),
                color: Colors.white,
                minHeight: 8,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 12),
              Text(
                "Ziel: ${user.goalValue} Schritte (${(progress * 100).toInt()}%)",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(UserModel user) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        _buildStatTile("Streak", "${user.streak} Tage", Icons.local_fire_department, Colors.orange),
        _buildStatTile("Workouts", "${user.workoutsThisWeek}/${user.workoutGoalWeekly}", Icons.fitness_center, Colors.blue),
        _buildStatTile("Punkte", "${user.points}", Icons.emoji_events, Colors.amber),
        _buildStatTile("XP bis Up", "${500 - (user.points % 500)}", Icons.trending_up, Colors.purple),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(FirebaseService db, String uid) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 150,
        child: FutureBuilder<List<DailyStatsModel>>(
          future: db.getWeeklyStats(uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LoadingSpinner();
            final stats = snapshot.data!;
            return BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 12000,
                barTouchData: BarTouchData(enabled: true),
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: stats.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.steps.toDouble(),
                        color: Theme.of(context).colorScheme.primary,
                        width: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
