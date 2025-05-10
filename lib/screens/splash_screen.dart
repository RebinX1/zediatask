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
  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAndTest();
  }

  Future<void> _initializeAndTest() async {
    try {
      // Brief delay to show splash screen
      await Future.delayed(const Duration(milliseconds: 1000));
      
      setState(() {
        _statusMessage = 'Testing connection...';
      });
      
      // Test Supabase connection
      final supabaseService = ref.read(supabaseServiceProvider);
      
      // Use the new checkDatabaseConnection method
      final isConnected = await supabaseService.checkDatabaseConnection();
      
      if (!isConnected) {
        setState(() {
          _hasError = true;
          _statusMessage = 'Database connection failed. Please check your network and try again.';
        });
        return;
      }
      
      setState(() {
        _statusMessage = 'Connection successful! Initializing services...';
      });
      
      // Initialize Supabase service (setup buckets, etc.)
      await supabaseService.initialize(setupStorage: true);
      
      setState(() {
        _statusMessage = 'Services initialized! Checking authentication...';
      });
      
      // Verify and refresh authentication if needed
      final isAuthValid = await supabaseService.verifyAndRefreshAuth();
      
      // Small delay to show success message
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
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            const Icon(
              Icons.task_alt,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            // App name
            Text(
              'ZediaTask',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 16),
            // Tagline
            Text(
              'Task Management Made Simple',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            if (!_hasError)
              const SpinKitDoubleBounce(
                color: AppTheme.primaryColor,
                size: 50.0,
              )
            else
              ElevatedButton(
                onPressed: _initializeAndTest,
                child: const Text('Retry Connection'),
              ),
            const SizedBox(height: 16),
            // Status message
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
    );
  }
} 