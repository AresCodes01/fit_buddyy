import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/daily_stats_model.dart';
import '../services/firebase_service.dart';
import '../services/step_tracker_service.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/common_widgets.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:isolate';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

import 'package:shared_preferences/shared_preferences.dart';

class _DashboardState extends State<Dashboard> {
  int _todayLiveSteps = 0;
  int? _lastSeenLevel;
  ReceivePort? _receivePort;

  @override
  void initState() {
    super.initState();
    _loadInitialSteps();
    _initBackgroundListener();
  }

  void _loadInitialSteps() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _todayLiveSteps = prefs.getInt('last_known_steps') ?? 0;
      });
    }
  }

  void _initBackgroundListener() async {
    final userModel = Provider.of<UserModel?>(context, listen: false);
    if (userModel == null) return;
    _lastSeenLevel = userModel.level;

    // Wir warten kurz, falls der Service gerade erst startet
    int retry = 0;
    while (!(await FlutterForegroundTask.isRunningService) && retry < 5) {
      await Future.delayed(const Duration(milliseconds: 500));
      retry++;
    }

    if (await FlutterForegroundTask.isRunningService) {
      _receivePort = FlutterForegroundTask.receivePort;
      _receivePort?.listen((message) {
        if (message is int && mounted) {
          setState(() => _todayLiveSteps = message);
          
          final todayId = DateTime.now().toString().split(' ')[0];
          context.read<FirebaseService>().updateSteps(userModel.id, todayId, message);
        }
      });
    }
  }

  @override
  void dispose() {
    _receivePort?.close();
    super.dispose();
  }

  void _checkLevelUp(int currentLevel) {
    if (_lastSeenLevel != null && currentLevel > _lastSeenLevel!) {
      _lastSeenLevel = currentLevel;
      Future.delayed(Duration.zero, () {
        _showLevelUpDialog(currentLevel);
      });
    }
  }

  void _showLevelUpDialog(int level) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🎉", style: TextStyle(fontSize: 50)),
            const Text("LEVEL UP!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Du hast Level $level erreicht!", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Weiter so!")),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final db = context.read<FirebaseService>();

    if (user == null) return const LoadingSpinner();
    _checkLevelUp(user.level);

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
    double xpProgress = (user.points % 500) / 500.0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Moin,", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              Text(user.displayName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showInfoDialog("Level Info", "Du steigst alle 500 XP ein Level auf. Aktuell fehlen dir noch ${500 - (user.points % 500)} XP."),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("Lvl ${user.level}", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: xpProgress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
        IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: provider.previousDay),
        Text(provider.formattedDate, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: provider.nextDay),
      ],
    );
  }

  Widget _buildMainStepCard(DashboardProvider provider, FirebaseService db, UserModel user) {
    return StreamBuilder<DailyStatsModel?>(
      stream: db.getDailyStats(user.id, provider.dateId),
      builder: (context, snapshot) {
        int steps = provider.isToday ? (_todayLiveSteps > 0 ? _todayLiveSteps : (snapshot.data?.steps ?? 0)) : (snapshot.data?.steps ?? 0);
        double progress = (steps / user.goalValue).clamp(0.0, 1.0);

        return GestureDetector(
          onTap: () => _showInfoDialog("Tagesziel", "Dein aktuelles Ziel sind ${user.goalValue} Schritte. Du kannst dies in den Einstellungen ändern."),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.directions_walk, color: Colors.white, size: 28), SizedBox(width: 10), Text("Heutige Schritte", style: TextStyle(color: Colors.white, fontSize: 18))]),
                const SizedBox(height: 20),
                Text("$steps", style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress, backgroundColor: Colors.white.withOpacity(0.3), color: Colors.white, minHeight: 8, borderRadius: BorderRadius.circular(10)),
                const SizedBox(height: 12),
                Text("Ziel: ${user.goalValue} (${(progress * 100).toInt()}%)", style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(UserModel user) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.5,
      children: [
        _buildStatTile("Streak", "${user.streak} Tage", Icons.local_fire_department, Colors.orange, () => _showInfoDialog("Serie", "Deine Streak zeigt an, wie viele Tage in Folge du aktiv warst. Nutze Streak Freezer (du hast ${user.streakFreezers}), um sie zu schützen!")),
        _buildStatTile("Workouts", "${user.workoutsThisWeek}/${user.workoutGoalWeekly}", Icons.fitness_center, Colors.blue, () => _showInfoDialog("Wochenziel", "Du hast dir vorgenommen, ${user.workoutGoalWeekly} Workouts pro Woche zu machen. Los geht's!")),
        _buildStatTile("Punkte", "${user.points}", Icons.emoji_events, Colors.amber, () => _showInfoDialog("Punkte", "XP sammelst du durch Schritte und Workouts. Jedes neue Level schenkt dir einen Streak Freezer!")),
        _buildStatTile("Freezer", "${user.streakFreezers}", Icons.ac_unit, Colors.lightBlueAccent, () => _showInfoDialog("Streak Freezer", "Ein Freezer schützt deine Serie automatisch, wenn du dein Ziel mal einen Tag lang nicht erreichst.")),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  Widget _buildWeeklyChart(FirebaseService db, String uid) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 180,
        child: StreamBuilder<List<DailyStatsModel>>(
          stream: db.getWeeklyStatsStream(uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text("Warte auf Daten..."));
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Noch keine Wochendaten."));

            // DATEN-CLEANUP: Wir gruppieren die Daten nach EINDEUTIGEM Tag
            final Map<String, DailyStatsModel> uniqueStats = {};
            for (var stat in snapshot.data!) {
              final dayKey = DateFormat('yyyy-MM-dd').format(stat.timestamp);
              // Falls zwei Einträge für einen Tag existieren, behalte den mit mehr Schritten
              if (!uniqueStats.containsKey(dayKey) || stat.steps > uniqueStats[dayKey]!.steps) {
                uniqueStats[dayKey] = stat;
              }
            }
            
            final stats = uniqueStats.values.toList();
            stats.sort((a, b) => a.timestamp.compareTo(b.timestamp));

            double maxSteps = 10000;
            for (var s in stats) { if (s.steps > maxSteps) maxSteps = s.steps.toDouble(); }

            return BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxSteps * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Theme.of(context).colorScheme.primary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem("${rod.toY.toInt()}", const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                    }
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < stats.length) {
                           final date = stats[index].timestamp;
                           return Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text(
                               DateFormat('E', 'de_DE').format(date), 
                               style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)
                             ),
                           );
                        }
                        return const Text("");
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
                  final isToday = DateFormat('yyyy-MM-dd').format(e.value.timestamp) == DateFormat('yyyy-MM-dd').format(DateTime.now());
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.steps.toDouble(),
                        color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        width: 14,
                        borderRadius: BorderRadius.circular(6),
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
