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
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.white,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.blue,
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.black,
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

    return StreamProvider<UserModel?>(
      key: ValueKey(firebaseUser.uid),
      create: (_) => firebaseService.getUserData(firebaseUser.uid),
      initialData: null,
      catchError: (context, error) {
        // Dies fängt Firestore-Fehler ab (z.B. PERMISSION_DENIED)
        return null; 
      },
      child: Consumer<UserModel?>(
        builder: (context, userModel, child) {
          if (userModel == null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text("Lade Profil..."),
                    const SizedBox(height: 10),
                    const Text(
                      "Hinweis: Wenn dies länger dauert, ist die Firebase-Datenbank eventuell noch nicht bereit.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () => firebaseService.signOut(),
                      child: const Text("Abbrechen & Logout"),
                    )
                  ],
                ),
              ),
            );
          }
          return const MainNavigation();
        },
      ),
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
        selectedItemColor: Colors.blueAccent,
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
