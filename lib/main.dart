import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:fit_buddyy/core/theme.dart';
import 'package:fit_buddyy/services/background_service.dart';

// Auth Feature
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/auth/domain/repositories/auth_repository.dart';
import 'package:fit_buddyy/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:fit_buddyy/features/auth/presentation/screens/auth_screen.dart';

// Home Feature
import 'package:fit_buddyy/features/home/domain/repositories/steps_repository.dart';
import 'package:fit_buddyy/features/home/data/repositories/firebase_steps_repository.dart';
import 'package:fit_buddyy/features/home/presentation/screens/dashboard_screen.dart';
import 'package:fit_buddyy/providers/dashboard_provider.dart';

// Workout Feature
import 'package:fit_buddyy/features/workout/domain/repositories/workout_repository.dart';
import 'package:fit_buddyy/features/workout/data/repositories/firebase_workout_repository.dart';
import 'package:fit_buddyy/features/workout/presentation/providers/workout_provider.dart';
import 'package:fit_buddyy/features/workout/presentation/screens/workout_tracking_screen.dart';

// Social Feature
import 'package:fit_buddyy/features/social/domain/repositories/social_repository.dart';
import 'package:fit_buddyy/features/social/data/repositories/firebase_social_repository.dart';
import 'package:fit_buddyy/features/social/presentation/screens/group_screen.dart';

// Profile Feature
import 'package:fit_buddyy/features/profile/presentation/screens/settings_screen.dart';

import 'package:fit_buddyy/providers/theme_provider.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await initializeDateFormatting('de_DE', null);
    
    BackgroundService.init();

    runApp(const FitBuddyApp());
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Startfehler: $e")))));
  }
}

class FitBuddyApp extends StatelessWidget {
  const FitBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositories
        Provider<AuthRepository>(create: (_) => FirebaseAuthRepository()),
        Provider<StepsRepository>(create: (_) => FirebaseStepsRepository()),
        Provider<SocialRepository>(create: (_) => FirebaseSocialRepository()),
        Provider<WorkoutRepository>(create: (_) => FirebaseWorkoutRepository()),
        
        // Providers
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(
          create: (context) => WorkoutProvider(context.read<WorkoutRepository>()),
        ),
        
        // Streams
        StreamProvider<User?>(
          create: (context) => context.read<AuthRepository>().authStateChanges,
          initialData: null,
        ),
      ],
      child: const RootApp(),
    );
  }
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = Provider.of<User?>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authRepository = Provider.of<AuthRepository>(context, listen: false);

    if (firebaseUser == null) {
      return MaterialApp(
        title: 'Fit Buddy',
        debugShowCheckedModeBanner: false,
        theme: FitBuddyTheme.buildTheme(Brightness.light),
        home: const AuthScreen(),
      );
    }

    return FutureBuilder(
      future: authRepository.syncOrCreateUser(firebaseUser),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: FitBuddyTheme.primaryColor,
                ),
              ),
            ),
          );
        }

        return StreamProvider<UserModel?>(
          key: ValueKey(firebaseUser.uid),
          create: (_) => authRepository.getUserData(firebaseUser.uid),
          initialData: null,
          child: Consumer<UserModel?>(
            builder: (context, userModel, child) {
              return MaterialApp(
                title: 'Fit Buddy',
                debugShowCheckedModeBanner: false,
                themeMode: themeProvider.themeMode,
                theme: FitBuddyTheme.buildTheme(Brightness.light),
                darkTheme: FitBuddyTheme.buildTheme(Brightness.dark),
                home: userModel == null 
                  ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                  : const MainNavigation(),
              );
            },
          ),
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startBackgroundTracking();
  }

  void _startBackgroundTracking() async {
    await [
      Permission.notification,
      Permission.activityRecognition,
    ].request();

    if (await Permission.activityRecognition.isGranted) {
      await Future.delayed(const Duration(seconds: 1));
      await BackgroundService.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [
      const Dashboard(),
      const WorkoutTrackingScreen(),
      const GroupScreen(),
      const SettingsScreen(),
    ];

    return WithForegroundTask(
      child: Scaffold(
        body: children[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Gruppen'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Einstellungen'),
          ],
        ),
      ),
    );
  }
}
