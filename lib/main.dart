import 'package:flutter/material.dart';
import 'screens/signin_screen.dart';
import 'screens/dashboard_screen.dart';
import 'package:flutter/services.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  await AuthService.instance.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.instance;
    
    Widget homeScreen;
    if (authService.isLoggedIn && authService.patientData != null) {
      final cnic = authService.patientData!['cnic'] ?? 
                   authService.patientData!['CNIC'] ?? '';
      homeScreen = DashboardScreen(cnic: cnic.toString());
    } else {
      homeScreen = const SignInScreen();
    }
    
    return MaterialApp(
      title: 'Healthcare Management System',
      useInheritedMediaQuery: true,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0f172a),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: homeScreen,
      debugShowCheckedModeBanner: false,
    );
  }
}

