// import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zediatask/constants/app_constants.dart';
import 'package:zediatask/firebase_options.dart';
import 'package:zediatask/providers/auth_provider.dart';
import 'package:zediatask/providers/task_provider.dart';
import 'package:zediatask/screens/auth/login_screen.dart';
import 'package:zediatask/screens/home/home_screen.dart';
import 'package:zediatask/screens/splash_screen.dart';
import 'package:zediatask/services/fcm_token_service.dart';
import 'package:zediatask/utils/app_theme.dart';
import 'package:zediatask/widgets/notification_handler.dart';

// Define background message handler - must be top level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Ensure Firebase is initialized for background handler
  debugPrint('Handling a background message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
  debugPrint('Notification title: ${message.notification?.title}');
  debugPrint('Notification body: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase for notifications - with catch-all error handling
  try {
    // Skip Firebase initialization in debug mode to avoid crashes
    // In production, you would use real Firebase config
    // if (!const bool.fromEnvironment('dart.vm.product')) {
    //   debugPrint('Skipping Firebase initialization in debug mode');
    // } else {
    //   await Firebase.initializeApp();
    //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    //   debugPrint('Firebase initialized successfully');
    // }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initializeFirebaseMessaging(); // Call the new function here
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // Continue without Firebase - the app will use mocked data
  }
  
  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    // Continue without Supabase - the app will use mocked data
  }
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

Future<void> _initializeFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission for notifications
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('User granted permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    debugPrint('User granted provisional permission');
  } else {
    debugPrint('User declined or has not accepted permission');
  }

  // Get the FCM token
  String? token = await messaging.getToken();
  debugPrint('Firebase Messaging Token: $token');

  // Set up token refresh handling using FCMTokenService
  try {
    final fcmTokenService = FCMTokenService();
    await fcmTokenService.handleTokenRefresh();
    debugPrint('FCM token refresh listener set up successfully');
  } catch (e) {
    debugPrint('Error setting up FCM token refresh listener: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize real-time subscriptions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeRealTimeSubscriptions(ref);
      
      // Save FCM token if user is logged in
      _saveFCMTokenIfLoggedIn();
    });
    
    // Wrap the app with NotificationHandler to handle task notifications
    return NotificationHandler(
      child: MaterialApp(
        title: 'Zedia',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const SplashScreen(),
          );
        },
      ),
    );
  }

  Future<void> _saveFCMTokenIfLoggedIn() async {
    try {
      // Add a delay to ensure Firebase is fully initialized
      await Future.delayed(const Duration(seconds: 3));
      
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final fcmTokenService = FCMTokenService();
        
        // Debug check first
        final debugToken = await fcmTokenService.getTokenForDebug();
        debugPrint('App startup - Debug token check: ${debugToken != null ? 'SUCCESS' : 'FAILED'}');
        
        if (debugToken != null) {
          await fcmTokenService.saveToken();
          debugPrint('FCM token saved for already logged in user');
        } else {
          debugPrint('Could not get FCM token during app startup');
        }
      }
    } catch (e) {
      debugPrint('Error saving FCM token for logged in user: $e');
    }
  }
}

// A very simple login screen that works without Supabase
class SimplifiedLoginScreen extends StatefulWidget {
  const SimplifiedLoginScreen({super.key});

  @override
  State<SimplifiedLoginScreen> createState() => _SimplifiedLoginScreenState();
}

class _SimplifiedLoginScreenState extends State<SimplifiedLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signIn() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Add a delay to simulate network request
    Future.delayed(const Duration(milliseconds: 800), () {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please enter email and password';
        });
        return;
      }

      // Simple validation - any email with @ will work with password "password"
      if (email.contains('@') && password == 'password') {
        // Set authentication state to true before navigating
        final container = ProviderScope.containerOf(context);
        container.read(isAuthenticatedProvider.notifier).state = true;
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid email or password. Try "test@example.com" with password "password"';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App logo
                const Icon(
                  Icons.task_alt,
                  size: 70,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                
                // App name
                Text(
                  'ZediaTask',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Tagline
                Text(
                  'Sign in to your account',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppTheme.errorColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Email field
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'test@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                // Password field
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                
                // Sign in button
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 16),
                
                // Help text
                const Text(
                  'Use email: test@example.com and password: password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}