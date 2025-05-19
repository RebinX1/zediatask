import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zediatask/providers/auth_provider.dart';
import 'package:zediatask/screens/auth/login_screen.dart';
import 'package:zediatask/screens/home/home_screen.dart';
import 'package:zediatask/utils/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _statusMessage = 'Loading...';
  bool _hasError = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAndTest();
  }

  Future<void> _initializeAndTest() async {
    try {
      // Brief delay to show splash screen
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Test Supabase connection silently
      final supabaseService = ref.read(supabaseServiceProvider);
      final isConnected = await supabaseService.checkDatabaseConnection();
      
      if (!isConnected) {
        throw Exception('Unable to connect to server');
      }
      
      // Initialize Supabase service silently
      await supabaseService.initialize(setupStorage: true);
      
      // Verify and refresh authentication silently
      final isAuthValid = await supabaseService.verifyAndRefreshAuth();
      
      // Small delay for visual consistency
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate based on auth status
      if (!mounted) return;
      
      final isAuthenticated = supabaseService.isAuthenticated();
      if (isAuthenticated) {
        // If authenticated, go to home screen
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // If not authenticated, go to login screen
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage = 'Connection error. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundColor, // Very dark blue
              AppTheme.primaryColor,   // Dark teal blue
              AppTheme.secondaryColor, // Medium teal blue
            ],
          ),
          image: DecorationImage(
            image: AssetImage('assets/images/triangle_pattern.png'),
            fit: BoxFit.cover,
            opacity: 0.15, // Make the pattern subtle
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Zedia logo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 80),
                child: Image.asset(
                  'assets/images/zedia_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              // App name
              Text(
                'Zedia',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 16),
              // Tagline
              Text(
                'Marketing & Task Management',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
              ),
              const SizedBox(height: 48),
              // Loading indicator
              if (!_hasError)
                const SpinKitDoubleBounce(
                  color: Colors.white,
                  size: 50.0,
                )
              else
                ElevatedButton(
                  onPressed: _initializeAndTest,
                  child: const Text('Retry'),
                ),
              const SizedBox(height: 16),
              // Status message
              if (_hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _hasError ? AppTheme.errorColor : AppTheme.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 