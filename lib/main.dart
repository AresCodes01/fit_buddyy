import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'models/user_model.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard.dart';
import 'screens/group_screen.dart';
import 'screens/workout_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FitBuddyApp());
}

class FitBuddyApp extends StatelessWidget {
  const FitBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return MultiProvider(
      providers: [
        Provider<FirebaseService>.value(value: firebaseService),
        StreamProvider<User?>(
          create: (_) => firebaseService.authState,
          initialData: null,
        ),
        StreamProvider<UserModel?>(
          create: (context) {
            final User? user = Provider.of<User?>(context, listen: false);
            return firebaseService.getUserData(user?.uid);
          },
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Fit Buddy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final userModel = Provider.of<UserModel?>(context);

    if (user == null) {
      return const AuthScreen();
    }

    if (userModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return const MainNavigation();
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
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fit Buddy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<FirebaseService>().signOut(),
          )
        ],
      ),
      body: children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Gruppen'),
        ],
      ),
    );
  }
}
