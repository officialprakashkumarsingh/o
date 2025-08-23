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
  
  // Load environment variables (optional - will use defaults if not found)
  try {
    // Try to load from assets first (for release builds)
    try {
      await dotenv.load();
      print('Environment variables loaded from assets successfully');
    } catch (e) {
      // If not in assets, try to load from file system (for debug builds)
      await dotenv.load(fileName: ".env");
      print('Environment variables loaded from file system successfully');
    }
  } catch (e) {
    print('Warning: Could not load .env file, using default values');
    print('Error: $e');
    // Continue without environment variables - will use hardcoded defaults
  }
  
  // Initialize core services
  try {
    await AppService.initialize();
    print('App services initialized successfully');
  } catch (e) {
    print('Error initializing app services: $e');
  }
  
  runApp(const AhamAIApp());
  
  // Set up error handling for the app
  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
  };
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
            
            // Smooth theme transitions and error handling
            builder: (context, child) {
              // Set up error widget
              ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 60,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Something went wrong!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            errorDetails.exception.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              };
              
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