import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'constants/app_colors.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/personal_details_screen.dart';
import 'screens/kyc_upload_screen.dart';
import 'screens/approval_pending_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/trip_process_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/background_service.dart';
import 'services/firebase_messaging_service.dart';
import 'widgets/location_permission_handler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found: $e");
  }

  // Initialize services
  initializeService()
      .catchError((e) => debugPrint("Background service error: $e"));

  try {
    await Firebase.initializeApp();
    await initializeFirebaseMessaging();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return LocationPermissionHandler(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Chola Cabs',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/otp': (context) => const VerificationScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/wallet': (context) => const WalletScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/menu': (context) => const MenuScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/personal_details': (context) => const PersonalDetailsScreen(),
          '/kyc_upload': (context) => const KycUploadScreen(),
          '/approval-pending': (context) => const ApprovalPendingScreen(),
          '/verification': (context) => const OTPVerificationScreen(),
          '/personal-details': (context) => const PersonalDetailsScreen(),
          '/kyc': (context) => const KycUploadScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/trip_process') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => TripProcessScreen(
                tripData: args ?? {},
              ),
            );
          }
          return null;
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
