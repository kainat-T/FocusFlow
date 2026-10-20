import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ThemeService().init();
  await NotificationService().init();
  runApp(const FocusFlowApp());
}

class FocusFlowApp extends StatelessWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        final current = ThemeService().currentTheme;
        return MaterialApp(
          title: 'FocusFlow',
          debugShowCheckedModeBanner: false,
          theme: current.toThemeData(),
          home: const AuthGate(),
        );
      },
    );
  }
}

class FFColors {
  static const ink     = Color(0xFF13171F);
  static const surface = Color(0xFF1C2230);
  static const brass   = Color(0xFFD4A24C);
  static const sage    = Color(0xFF74957C);
  static const parchment = Color(0xFFEDE7DA);
  static const slate   = Color(0xFF8B93A6);
}
