import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/services/app_service.dart';
import 'core/services/model_service.dart';
import 'theme/providers/theme_provider.dart';
import 'features/splash/pages/splash_page.dart';
import 'utils/app_scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize core services
  await AppService.initialize();
  
  runApp(const AhamAIApp());
}

class AhamAIApp extends StatelessWidget {
  const AhamAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: ModelService.instance),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AhamAI',
            debugShowCheckedModeBanner: false,
            
            // Theme configuration
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            
            // Ultra-smooth scroll behavior
            scrollBehavior: AppScrollBehavior(),
            
            // Smooth theme transitions
            builder: (context, child) {
              return AnimatedTheme(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                data: Theme.of(context),
                child: child ?? const SizedBox.shrink(),
              );
            },
            
            home: const SplashPage(),
          );
        },
      ),
    );
  }
}