import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'constants/app_colors.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/no_network_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/personal_details_screen.dart';
import 'screens/auth/kyc_upload_screen.dart';
import 'screens/admin/approval_pending_screen.dart';
import 'screens/admin/contact_admin_screen.dart';
import 'screens/admin/device_blocked_screen.dart';
import 'screens/profile/wallet_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/notifications_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/trip/trip_process_screen.dart';
import 'services/background_service.dart';
import 'services/firebase_messaging_service.dart';
import 'services/permission_service.dart';
import 'services/notification_plugin.dart';
import 'services/connectivity_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found: $e");
  }

  // Initialize notification plugin first
  await NotificationPlugin.initialize();

  try {
    await Firebase.initializeApp();
    await initializeFirebaseMessaging();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  await ConnectivityService().initialize();

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
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Chola Cabs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      builder: (context, child) {
        return StreamBuilder<bool>(
          stream: ConnectivityService().connectionStatus,
          initialData: true,
          builder: (context, snapshot) {
            final hasConnection = snapshot.data ?? true;
            if (!hasConnection) {
              return const NoNetworkScreen();
            }
            return child ?? const SizedBox();
          },
        );
      },
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/registration': (context) => const PersonalDetailsScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/wallet': (context) => const WalletScreen(),
        '/profile': (context) => const ProfileScreen(),

        '/notifications': (context) => const NotificationsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/approval-pending': (context) => const ApprovalPendingScreen(),
        '/personal-details': (context) => const PersonalDetailsScreen(),
        '/kyc': (context) => const KycUploadScreen(),
        '/kyc_upload': (context) => const KycUploadScreen(),
        '/contact-admin': (context) => const ContactAdminScreen(),
        '/device-blocked': (context) => const DeviceBlockedScreen(),
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
        if (settings.name == '/verification') {
          final phoneNumber = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(phoneNumber: phoneNumber),
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
