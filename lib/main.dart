import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/api_config.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/inactivity_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  try {
    await ApiConfig.loadConfig();
  } catch (_) {}
  
  await AuthService.instance.init();
  await ThemeService.instance.init();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    InactivityService.instance.setNavigatorKey(_navigatorKey);
    InactivityService.instance.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    InactivityService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When app resumes, check if user should be logged out due to inactivity
      InactivityService.instance.checkInactivity();
    } else if (state == AppLifecycleState.paused) {
      // App is going to background - timer will continue running
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => InactivityService.instance.resetActivity(),
      onPointerMove: (_) => InactivityService.instance.resetActivity(),
      onPointerUp: (_) => InactivityService.instance.resetActivity(),
      child: ValueListenableBuilder<AppThemeMode>(
        valueListenable: ThemeService.instance.themeNotifier,
        builder: (context, _, __) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Healthcare Management System',
            navigatorObservers: [
              _InactivityObserver(),
            ],
            theme: ThemeService.instance.getTheme(),
            darkTheme: ThemeService.instance.getDarkTheme(),
            themeMode: ThemeService.instance.getThemeMode(),
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

/// NavigatorObserver that tracks user interactions to reset inactivity timer
class _InactivityObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    InactivityService.instance.resetActivity();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    InactivityService.instance.resetActivity();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    InactivityService.instance.resetActivity();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    InactivityService.instance.resetActivity();
  }
}

