import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_home_security/features/splash/screens/splash_screen.dart';
import 'package:smart_home_security/features/auth/screens/home_code_screen.dart';
import 'package:smart_home_security/features/auth/screens/login_screen.dart';
import 'package:smart_home_security/features/auth/screens/register_screen.dart';
import 'package:smart_home_security/features/home/screens/main_screen.dart';
import 'package:smart_home_security/features/cameras/screens/cameras_screen.dart';
import 'package:smart_home_security/features/access/screens/guest_access_screen.dart';
import 'package:smart_home_security/features/control/screens/home_control_screen.dart';
import 'package:smart_home_security/features/sensors/screens/sensors_screen.dart';
import 'package:smart_home_security/features/settings/screens/settings_screen.dart';
import 'package:smart_home_security/features/settings/screens/profile_screen.dart';
import 'package:smart_home_security/features/settings/screens/change_password_screen.dart';
import 'package:smart_home_security/features/settings/screens/members_screen.dart';
import 'package:smart_home_security/features/web/screens/pfe_web_screen.dart';

/// مسارات التطبيق
class AppRoutes {
  static const String splash = '/';
  static const String homeCode = '/home-code';
  static const String login = '/login';
  static const String register = '/register';
  static const String main = '/main';
  static const String cameras = '/cameras';
  static const String cameraView = '/camera/:id';
  static const String guestAccess = '/guest-access';
  static const String homeControl = '/home-control';
  static const String sensors = '/sensors';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String changePassword = '/change-password';
  static const String members = '/members';
  static const String pfeWeb = '/pfe-web';
}

/// إعدادات الراوتر
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      
      // Home Code Entry
      GoRoute(
        path: AppRoutes.homeCode,
        name: 'homeCode',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeCodeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideUpTransition(animation, child);
          },
        ),
      ),
      
      // Login
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),
      
      // Register
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),
      
      // Main Screen with Bottom Navigation
      GoRoute(
        path: AppRoutes.main,
        name: 'main',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _scaleTransition(animation, child);
          },
        ),
      ),
      
      // Cameras
      GoRoute(
        path: AppRoutes.cameras,
        name: 'cameras',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CamerasScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),
      
      // Guest Access
      GoRoute(
        path: AppRoutes.guestAccess,
        name: 'guestAccess',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const GuestAccessScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideUpTransition(animation, child);
          },
        ),
      ),
      
      // Home Control
      GoRoute(
        path: AppRoutes.homeControl,
        name: 'homeControl',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeControlScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),
      
      // Sensors & Alerts
      GoRoute(
        path: AppRoutes.sensors,
        name: 'sensors',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SensorsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),
      
      // Settings
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),
      
      // Profile
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),
      
      // Change Password
      GoRoute(
        path: AppRoutes.changePassword,
        name: 'changePassword',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ChangePasswordScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),
      
      // Members
      GoRoute(
        path: AppRoutes.members,
        name: 'members',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MembersScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),

      // PFE Web
      GoRoute(
        path: AppRoutes.pfeWeb,
        name: 'pfeWeb',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PfeWebScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _slideLeftTransition(animation, child);
          },
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'الصفحة غير موجودة',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    ),
  );
  
  // ======== Transition Animations ========
  
  static Widget _slideUpTransition(Animation<double> animation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
  
  static Widget _slideLeftTransition(Animation<double> animation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
  
  static Widget _scaleTransition(Animation<double> animation, Widget child) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
