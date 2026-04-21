import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'models/user_model.dart';
import 'providers/dashboard_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard.dart';
import 'screens/group_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/settings_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await initializeDateFormatting('de_DE', null);
    runApp(const FitBuddyApp());
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Fehler: $e")))));
  }
}

class FitBuddyApp extends StatelessWidget {
  const FitBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    // "Eco Pulse" Farbpalette
    const Color primaryTeal = Color(0xFF00BFA5);
    const Color lightBg = Color(0xFFF0FDF4); // Ganz zarter Grün-Stich

    return MultiProvider(
      providers: [
        Provider<FirebaseService>.value(value: firebaseService),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        StreamProvider<User?>(
          create: (_) => firebaseService.authState,
          initialData: null,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Fit Buddy',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: primaryTeal,
                brightness: Brightness.light,
                primary: primaryTeal,
              ),
              scaffoldBackgroundColor: lightBg,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: primaryTeal,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF0A1210), // Sehr dunkles Teal-Schwarz
            ),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = Provider.of<User?>(context);
    final firebaseService = Provider.of<FirebaseService>(context);

    if (firebaseUser == null) {
      return const AuthScreen();
    }

    return FutureBuilder(
      future: firebaseService.syncOrCreateUser(firebaseUser),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text("Initialisierungsfehler: ${snapshot.error}")));
        }

        return StreamProvider<UserModel?>(
          key: ValueKey(firebaseUser.uid),
          create: (_) => firebaseService.getUserData(firebaseUser.uid),
          initialData: null,
          child: Consumer<UserModel?>(
            builder: (context, userModel, child) {
              if (userModel == null) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return const MainNavigation();
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
  Widget build(BuildContext context) {
    final List<Widget> children = [
      const Dashboard(),
      const WorkoutScreen(),
      const GroupScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
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
    );
  }
}
