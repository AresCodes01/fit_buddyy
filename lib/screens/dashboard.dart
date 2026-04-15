import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/user_model.dart';
import '../models/daily_stats_model.dart';
import '../services/firebase_service.dart';
import '../services/step_tracker_service.dart';
import '../providers/dashboard_provider.dart';

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
          final provider = Provider.of<DashboardProvider>(context, listen: false);
          setState(() {
            _todayLiveSteps = steps;
          });
          // Nur in Firebase speichern, wenn wir gerade den heutigen Tag betrachten
          // Oder immer speichern, aber die UI zeigt den historischen Wert
          // Best practice: Immer speichern für das heutige Datum
          final todayId = provider.isToday ? provider.dateId : DateTime.now().toString().split(' ')[0];
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

    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildDateNavigation(context, dashboardProvider),
              const SizedBox(height: 40),
              _buildStepCircle(dashboardProvider, db, user.id),
              const SizedBox(height: 40),
              _buildWeeklyChart(db, user.id),
              const SizedBox(height: 20),
              _buildStatsRow(user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigation(BuildContext context, DashboardProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blueAccent),
          onPressed: provider.previousDay,
        ),
        Column(
          children: [
            Text(
              provider.formattedDate,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (!provider.isToday)
              TextButton(
                onPressed: provider.goToToday,
                child: const Text("Zurück zu Heute", style: TextStyle(color: Colors.blueAccent)),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
          onPressed: provider.nextDay,
        ),
      ],
    );
  }

  Widget _buildStepCircle(DashboardProvider provider, FirebaseService db, String uid) {
    return StreamBuilder<DailyStatsModel?>(
      stream: db.getDailyStats(uid, provider.dateId),
      builder: (context, snapshot) {
        int steps = 0;
        if (provider.isToday) {
          steps = _todayLiveSteps > 0 ? _todayLiveSteps : (snapshot.data?.steps ?? 0);
        } else {
          steps = snapshot.data?.steps ?? 0;
        }

        return Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 15),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_walk, size: 50, color: Colors.blueAccent),
                Text(
                  '$steps',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const Text("Schritte", style: TextStyle(color: Colors.grey, fontSize: 18)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyChart(FirebaseService db, String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Letzte 7 Tage", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: FutureBuilder<List<DailyStatsModel>>(
            future: db.getWeeklyStats(uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final stats = snapshot.data!;
              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 15000, // Beispielziel
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return const Text(""); // Vereinfacht für dieses Beispiel
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: stats.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.steps.toDouble(),
                          color: Colors.blueAccent,
                          width: 15,
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
      ],
    );
  }

  Widget _buildStatsRow(UserModel user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem("Streak", "${user.streak} Tage", Icons.local_fire_department, Colors.orange),
        _buildStatItem("Ziel", "10.000", Icons.flag, Colors.green),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
