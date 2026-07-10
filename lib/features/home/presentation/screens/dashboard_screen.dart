import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/home/domain/models/daily_stats_model.dart';
import 'package:fit_buddyy/features/home/domain/repositories/steps_repository.dart';
import 'package:fit_buddyy/features/social/domain/repositories/social_repository.dart';
import 'package:fit_buddyy/providers/dashboard_provider.dart';
import 'package:fit_buddyy/widgets/common_widgets.dart';
import 'package:fit_buddyy/features/social/presentation/screens/chat_screen.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:fit_buddyy/services/vibration_service.dart';
import 'package:fit_buddyy/providers/ai_buddy_provider.dart';
import 'package:fit_buddyy/features/home/presentation/screens/ai_buddy_chat_screen.dart';
import 'package:fit_buddyy/features/auth/presentation/screens/link_account_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _todayLiveSteps = 0;
  int? _lastSeenLevel;
  late ConfettiController _confettiController;
  int _stepsAtLastFirebaseUpdate = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadInitialSteps();
    _initBackgroundListener();
  }

  void _loadInitialSteps() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    final lastSavedDate = prefs.getString('last_step_date') ?? '';
    final userModel = Provider.of<UserModel?>(context, listen: false);

    if (mounted) {
      setState(() {
        if (lastSavedDate == today) {
          _todayLiveSteps = prefs.getInt('last_known_steps_today') ?? 0;
          _stepsAtLastFirebaseUpdate = _todayLiveSteps;
        } else {
          _todayLiveSteps = 0;
          _stepsAtLastFirebaseUpdate = 0;
          
          // Wenn ein neuer Tag ist, forcen wir den Reset in Firebase sofort
          if (userModel != null) {
            context.read<StepsRepository>().updateSteps(userModel.id, today, 0);
            _saveStepsLocally(0);
          }
        }
      });
    }
  }

  void _onReceiveTaskData(Object message) {
    if (message is int && mounted) {
      final userModel = Provider.of<UserModel?>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
      if (userModel == null) return;

      setState(() => _todayLiveSteps = message);

      // Persistenz für App-Neustarts
      _saveStepsLocally(message);
      
      if (userModel.goalValue > 0 && message >= userModel.goalValue && !dashboardProvider.goalAnimationShownToday) {
        dashboardProvider.setGoalAnimationShown(true);
        _confettiController.play();
        VibrationService.success();
        Future.delayed(Duration.zero, () {
          if (mounted) _showLevelUpDialog(title: "ZIEL ERREICHT!", message: "Du hast dein Tagesziel von ${userModel.goalValue} Schritten geschafft!");
        });
      }

      // Buffer: Nur an Firebase senden, wenn mindestens 50 Schritte Unterschied oder initial 0
      if ((message - _stepsAtLastFirebaseUpdate).abs() >= 50 || _stepsAtLastFirebaseUpdate == 0) {
        _stepsAtLastFirebaseUpdate = message;
        final todayId = DateTime.now().toString().split(' ')[0];
        context.read<StepsRepository>().updateSteps(userModel.id, todayId, message);
      }
    }
  }

  void _initBackgroundListener() async {
    final userModel = Provider.of<UserModel?>(context, listen: false);
    if (userModel == null) return;
    _lastSeenLevel = userModel.level;

    // Trigger AI motivation - Jetzt entkoppelt und ohne Blockierung
    Future.delayed(Duration.zero, () {
      if (mounted) {
        // Wir fangen Fehler hier ab, damit sie den Start nicht stören
        context.read<AiBuddyProvider>().fetchDailyMotivation(userModel, _todayLiveSteps).catchError((e) {
          debugPrint("AI Startup Error: $e");
        });
      }
    });

    int retry = 0;
    while (!(await FlutterForegroundTask.isRunningService) && retry < 5) {
      await Future.delayed(const Duration(milliseconds: 500));
      retry++;
    }

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _confettiController.dispose();
    super.dispose();
  }

  void _saveStepsLocally(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    await prefs.setInt('last_known_steps_today', steps);
    await prefs.setString('last_step_date', today);
  }

  void _checkLevelUp(int currentLevel) {
    if (_lastSeenLevel != null && currentLevel > _lastSeenLevel!) {
      _lastSeenLevel = currentLevel;
      _confettiController.play();
      VibrationService.levelUp();
      Future.delayed(Duration.zero, () {
        _showLevelUpDialog(level: currentLevel);
      });
    }
  }

  void _checkGoalReached(int steps, int goal, DashboardProvider provider) {
    if (!provider.isToday) return; 
    if (goal > 0 && steps >= goal && !provider.goalAnimationShownToday) {
      provider.setGoalAnimationShown(true);
      _confettiController.play();
      VibrationService.success();
      Future.delayed(Duration.zero, () {
        if (mounted) _showLevelUpDialog(title: "ZIEL ERREICHT!", message: "Du hast dein Tagesziel von $goal Schritten geschafft!");
      });
    }
  }

  void _showLevelUpDialog({int? level, String? title, String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🎉", style: TextStyle(fontSize: 50)),
            Text(title ?? "LEVEL UP!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(message ?? "Du hast Level $level erreicht!", style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
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
    final user = context.select<UserModel?, UserModel?>((u) => u);
    // WICHTIG: watch nutzen, damit bei JEDER Änderung im Provider (z.B. Pfeil-Klick) 
    // das gesamte Widget neu gebaut wird!
    final dashboardProvider = context.watch<DashboardProvider>();
    final stepsRepo = context.read<StepsRepository>();

    if (user == null) return const LoadingSpinner();
    _checkLevelUp(user.level);
    _checkGoalReached(_todayLiveSteps, user.goalValue, dashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (user.isAnonymous) ...[
                        const SizedBox(height: 10),
                        _buildGuestWarning(context),
                      ],
                      const SizedBox(height: 20),
                      _buildHeader(user),
                      const SizedBox(height: 10),
                      _buildAiBuddyCard(context, user),
                      const SizedBox(height: 10),
                      _buildDateNavigation(context, dashboardProvider),
                      const SizedBox(height: 30),
                      _buildProgressRing(provider: dashboardProvider, stepsRepo: stepsRepo, user: user),
                      const SizedBox(height: 30),
                      const SectionTitle("Dein Status"),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: _buildStatsGrid(user, dashboardProvider, stepsRepo),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Deine Gruppen",
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 18, 
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text("Alle zeigen"),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: _buildGroupSwiper(user, context.read<SocialRepository>()),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 25),
                      const SectionTitle("Wochen-Trend"),
                      _buildWeeklyChart(stepsRepo, user.id),
                      const SizedBox(height: 30),
                    ]),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBuddyCard(BuildContext context, UserModel user) {
    if (user.isAnonymous) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Text("🔒", style: TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "KI Buddy gesperrt",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Registriere dich, um deinen persönlichen KI-Buddy freizuschalten!",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final aiProvider = Provider.of<AiBuddyProvider>(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AiBuddyChatScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.8),
              Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Text("🤖", style: TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Fit Buddyy Nachricht",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  aiProvider.isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          aiProvider.dailyMotivation,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestWarning(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSecondaryContainer, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Gast-Modus: Sichere deine Erfolge!",
              style: TextStyle(
                fontSize: 14, 
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LinkAccountScreen()),
              );
            },
            child: const Text("Jetzt sichern", style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    double xpProgress = (user.points % 500) / 500.0;
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : "?",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hallo,", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              Text(user.displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
        IconButton(
          icon: Icon(
            Icons.arrow_forward_ios, 
            size: 18, 
            color: provider.canGoNext ? null : Colors.grey.withValues(alpha: 0.3),
          ), 
          onPressed: provider.canGoNext ? provider.nextDay : null,
        ),
      ],
    );
  }

  Widget _buildProgressRing({
    required DashboardProvider provider,
    required StepsRepository stepsRepo,
    required UserModel user,
  }) {
    return StreamBuilder<DailyStatsModel?>(
      key: ValueKey("steps_${provider.dateId}"), // Eindeutiger Key pro Tag
      stream: stepsRepo.getDailyStats(user.id, provider.dateId),
      builder: (context, snapshot) {
        // Logik für die Anzeige:
        int steps = 0;
        if (provider.isToday) {
          // Heute: Live-Schritte oder letzter bekannter Wert
          steps = _todayLiveSteps > 0 ? _todayLiveSteps : (snapshot.data?.steps ?? 0);
        } else {
          // Historie: Nur die Daten aus dem Snapshot
          steps = snapshot.data?.steps ?? 0;
          
          // Falls wir noch laden, zeigen wir kurz einen Spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 200,
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
        }

        double progress = user.goalValue > 0 ? (steps / user.goalValue).clamp(0.0, 1.0) : 0.0;

        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 14,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_walk, size: 28, color: Colors.grey),
                  const SizedBox(height: 4),
                  Text(
                    "$steps",
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "von ${user.goalValue}",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupSwiper(UserModel user, SocialRepository socialRepo) {
    if (user.groupIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_off, color: Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text("Noch in keiner Gruppe", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: socialRepo.getGroups(user.groupIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final groups = snapshot.data!;

        return PageView.builder(
          controller: PageController(viewportFraction: 0.85),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return _buildGroupCard(group, user, socialRepo);
          },
        );
      },
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group, UserModel currentUser, SocialRepository socialRepo) {
    return StreamBuilder<List<UserModel>>(
      stream: socialRepo.getGroupMembers(group['id']),
      builder: (context, snapshot) {
        int rank = 0;
        int totalMembers = 0;
        int topSteps = 0;

        if (snapshot.hasData) {
          final members = snapshot.data!;
          totalMembers = members.length;
          members.sort((a, b) => b.dailySteps.compareTo(a.dailySteps));
          rank = members.indexWhere((m) => m.id == currentUser.id) + 1;
          topSteps = members.isNotEmpty ? members.first.dailySteps : 0;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  groupId: group['id'],
                  groupName: group['name'],
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(right: 12, bottom: 8, top: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.group, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          group['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Dein Rang", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(
                            rank > 0 ? "#$rank von $totalMembers" : "- / -",
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 18, 
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Top-Leistung", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(
                            "$topSteps",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(UserModel user, DashboardProvider provider, StepsRepository stepsRepo) {
    return StreamBuilder<DailyStatsModel?>(
      key: ValueKey("stats_${provider.dateId}"), // Zwingt zum Neuzeichnen bei Datumswechsel
      stream: stepsRepo.getDailyStats(user.id, provider.dateId),
      builder: (context, snapshot) {
        int steps = 0;
        if (provider.isToday) {
          steps = _todayLiveSteps > 0 ? _todayLiveSteps : (snapshot.data?.steps ?? 0);
        } else {
          steps = snapshot.data?.steps ?? 0;
        }
        
        double km = (steps * 0.00075); 
        int kcal = (steps * 0.04).toInt();

        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          delegate: SliverChildListDelegate([
            _buildStatTile("Distanz", "${km.toStringAsFixed(2)} km", Icons.straighten, Colors.blue),
            _buildStatTile("Kalorien", "$kcal kcal", Icons.local_fire_department, Colors.orange),
            _buildStatTile("Streak", "${user.streak} Tage", Icons.bolt, Colors.amber),
            _buildStatTile("Punkte", "${user.points} XP", Icons.stars, Colors.purple),
          ]),
        );
      },
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Verteilt Icon oben und Text unten
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(StepsRepository stepsRepo, String uid) {
    return CustomCard(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: SizedBox(
        height: 220,
        child: StreamBuilder<List<DailyStatsModel>>(
          stream: stepsRepo.getWeeklyStatsStream(uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text("Warte auf Daten..."));
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Noch keine Wochendaten."));

            final Map<String, DailyStatsModel> uniqueStats = {};
            for (var stat in snapshot.data!) {
              final dayKey = DateFormat('yyyy-MM-dd').format(stat.timestamp);
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
                               style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)
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
                        color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        width: 18,
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
