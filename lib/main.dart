




// // import 'package:flutter/material.dart';
// // import 'package:nahata_app/screens/location_screen.dart';
// // import 'package:nahata_app/screens/login_screen.dart';
// // import 'package:nahata_app/screens/payment_screen.dart';
// // import 'package:nahata_app/screens/registration.dart';
// // import 'package:nahata_app/splash_screen.dart';
// //
// // void main() {
// //   runApp(const MyApp());
// // }
// //
// // class MyApp extends StatelessWidget {
// //   const MyApp({super.key});
// //
// //   // This widget is the root of your application.
// //   @override
// //   Widget build(BuildContext context) {
// //     return  MaterialApp(
// //       title: 'Nahata Sports Booking',
// //       theme: ThemeData(
// //         primarySwatch: Colors.indigo,
// //       ),
// //       debugShowCheckedModeBanner: false,
// //
// //       initialRoute: '/',
// //       routes: {
// //         '/': (context) => const SplashScreen(),
// //         '/signup': (context) => const SignUpScreen(),
// //         // '/login': (context) => const LoginScreen(),
// //           '/login': (context) => const LoginScreen(),
// //           '/location': (context) => const LocationScreen(),
// //             '/payment': (context) {
// //               final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
// //               return PaymentScreen(bookingDetails: args);
// //             },
// //       },
// //     );
// //   }
// // }
//
//
//
//
// import 'dart:async';
// import 'dart:io';
// import 'package:device_preview/device_preview.dart';
// import 'package:flutter/material.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/services.dart';
// import 'package:nahata_app/screens/location_screen.dart';
// import 'package:nahata_app/screens/login_screen.dart';
// import 'package:nahata_app/screens/payment_screen.dart';
// import 'package:nahata_app/screens/registration.dart';
// import 'package:nahata_app/services/api_service.dart';
// import 'package:nahata_app/splash_screen.dart';
//
// import 'dashboard/admin_screen.dart';
//
// import 'dashboard/coach_screen.dart';
// import 'dashboard/dashboard_screen.dart';
// import 'dashboard/security_screen.dart';
// import 'dashboard/students_parents.dart';
//
//
// void main() async{
//   WidgetsFlutterBinding.ensureInitialized();
//   await ApiService.loadUserFromPrefs(); // restore session
//   SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return InternetCheckWrapper(
//       child: MaterialApp(
//         title: 'Nahata Sports Booking',
//         theme: ThemeData( primarySwatch: Colors.indigo, ),
//
//         debugShowCheckedModeBanner: false,
//         initialRoute: '/',
//
//         routes: {
//           '/': (context) => const InternetCheckWrapper(child: SplashScreen()),
//           '/signup': (context) => InternetCheckWrapper(child: SignUpScreen()),
//           '/login': (context) => const InternetCheckWrapper(child: LoginScreen()),
//           '/location': (context) => const InternetCheckWrapper(child: LocationScreen()),
//           // '/dashboard': (context) => const InternetCheckWrapper(child: DashboardScreen()),
//           '/students_parents': (context) =>  InternetCheckWrapper(child: StudentsParentsScreen(studentId: ApiService.currentUser?['student_id']?.toString() ?? '',)),
//           // '/roleselection': (context) => const InternetCheckWrapper(child: RoleSelectionScreen()),
//           '/payment': (context) {
//             final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
//             return InternetCheckWrapper(
//               child: PaymentScreen(bookingDetails: args),
//             );
//             },
//           '/dashboard': (context) => const InternetCheckWrapper(child: BookPlayScreen()),
//           '/coachscreen': (context) => const InternetCheckWrapper(child: CoachDashboardScreen()),
//           '/adminscreen': (context) => const InternetCheckWrapper(child: AdminDashboardScreen()),
//           '/securityscreen': (context) => const InternetCheckWrapper(child: SecurityGateScannerScreen()),
//         },
//       ),
//     );
//   }
// }
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
// //
// // void main() {
// //   runApp(const MyApp());
// // }
// // void main() {
// //   runApp(
// //     DevicePreview(
// //       enabled: true, // Set to false for release builds
// //       builder: (context) => MyApp(),
// //     ),
// //   );
// // }
//
//
//
//
//
//
//
//
//
//
//
//
//
//
// // /// ✅ InternetCheckWrapper monitors connectivity and shows popup if offline
// // class InternetCheckWrapper extends StatefulWidget {
// //   final Widget child;
// //   const InternetCheckWrapper({super.key, required this.child});
// //
// //   @override
// //   State<InternetCheckWrapper> createState() => _InternetCheckWrapperState();
// // }
// //
// // class _InternetCheckWrapperState extends State<InternetCheckWrapper> {
// //   late final _subscription;
// //   bool _dialogIsOpen = false;
// //   BuildContext? _dialogContext;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       _checkInternet();
// //     });
// //
// //     // Listen to connectivity changes
// //     _subscription = Connectivity().onConnectivityChanged.listen((_) {
// //       _checkInternet();
// //     });
// //   }
// //
// //   Future<void> _checkInternet() async {
// //     bool hasInternet = await _hasInternet();
// //
// //     if (!hasInternet && !_dialogIsOpen) {
// //       _showNoInternetDialog();
// //     } else if (hasInternet && _dialogIsOpen && _dialogContext != null) {
// //       Navigator.pop(_dialogContext!); // close dialog automatically
// //       _dialogIsOpen = false;
// //       _dialogContext = null;
// //     }
// //   }
// //
// //   Future<bool> _hasInternet() async {
// //     try {
// //       final result = await InternetAddress.lookup('example.com');
// //       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
// //     } on SocketException catch (_) {
// //       return false;
// //     }
// //   }
// //
// //   void _showNoInternetDialog() {
// //     _dialogIsOpen = true;
// //
// //   //   showDialog(
// //   //     context: context,
// //   //     barrierDismissible: false,
// //   //     builder: (dialogContext) {
// //   //       _dialogContext = dialogContext;
// //   //       return const AlertDialog(
// //   //         title: Text("No Internet"),
// //   //         content: Text("Please check your internet connection."),
// //   //       );
// //   //     },
// //   //   ).then((_) {
// //   //     _dialogIsOpen = false;
// //   //     _dialogContext = null;
// //   //   });
// //   // }
// //
// //
// //     showDialog(
// //       context: context,
// //       barrierDismissible: false, // cannot dismiss by tapping outside
// //       builder: (context) => WillPopScope(
// //         // prevent back button closing
// //         onWillPop: () async => false,
// //         child: AlertDialog(
// //           title: const Text("No Internet"),
// //           content: const Text("Please check your internet connection."),
// //           actions: [
// //             TextButton(
// //               onPressed: () async {
// //                 bool hasInternet = await _hasInternet();
// //                 if (hasInternet) {
// //                   Navigator.of(context, rootNavigator: true).pop();
// //                   _dialogIsOpen = false;
// //                 }
// //                 // if no internet → keep dialog open
// //               },
// //               child: const Text("Retry"),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   @override
// //   void dispose() {
// //     _subscription.cancel();
// //     super.dispose();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return widget.child;
// //   }
// // }
//
//
// class InternetCheckWrapper extends StatefulWidget {
//   final Widget child;
//   const InternetCheckWrapper({super.key, required this.child});
//
//   @override
//   State<InternetCheckWrapper> createState() => _InternetCheckWrapperState();
// }
//
// class _InternetCheckWrapperState extends State<InternetCheckWrapper> {
//   late StreamSubscription<List<ConnectivityResult>> _subscription;
//   bool _dialogIsOpen = false;
//
//   @override
//   void initState() {
//     super.initState();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkInternet();
//     });
//
//     _subscription = Connectivity().onConnectivityChanged.listen((results) {
//       // results is List<ConnectivityResult>
//       _checkInternet();
//     });
//   }
//
//   // Future<void> _checkInternet() async {
//   //   bool hasInternet = await _hasInternet();
//   //
//   //   if (!mounted) return; // widget not ready
//   //
//   //   if (!hasInternet && !_dialogIsOpen) {
//   //     _showNoInternetDialog();
//   //   } else if (hasInternet && _dialogIsOpen) {
//   //     // Ensure navigator is ready before popping
//   //     WidgetsBinding.instance.addPostFrameCallback((_) {
//   //       if (mounted) {
//   //         Navigator.of(context, rootNavigator: true).pop();
//   //         _dialogIsOpen = false;
//   //       }
//   //     });
//   //   }
//   // }
//
//   // Future<void> _checkInternet() async {
//   //   bool hasInternet = await _hasInternet();
//   //
//   //   if (!hasInternet && !_dialogIsOpen) {
//   //     _showNoInternetDialog();
//   //   } else if (hasInternet && _dialogIsOpen) {
//   //     // Internet restored → close popup automatically
//   //     Navigator.of(context, rootNavigator: true).pop();
//   //     _dialogIsOpen = false;
//   //   }
//   // }
//
//   Future<bool> _hasInternet() async {
//     try {
//       final result = await InternetAddress.lookup('example.com');
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } on SocketException catch (_) {
//       return false;
//     }
//   }
//   //
//   // void _showNoInternetDialog() {
//   //   _dialogIsOpen = true;
//   //
//   //   showDialog(
//   //     context: context,
//   //     barrierDismissible: false, // cannot dismiss manually
//   //     builder: (context) => WillPopScope(
//   //       onWillPop: () async => false, // disable back button
//   //       child: const AlertDialog(
//   //         title: Text("No Internet"),
//   //         content: Text("Please check your internet connection."),
//   //       ),
//   //     ),
//   //   ).then((_) {
//   //     _dialogIsOpen = false;
//   //   });
//   // }
//
//
//
//
//   void _showNoInternetDialog() {
//     _dialogIsOpen = true;
//
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         title: const Text("No Internet"),
//         content: const Text("Please check your internet connection."),
//         actions: [
//           TextButton(
//             onPressed: () async {
//               Navigator.of(context, rootNavigator: true).pop(); // close dialog
//               _dialogIsOpen = false;
//               _checkInternet(); // retry check
//             },
//             child: const Text("Retry"),
//           ),
//         ],
//       ),
//     ).then((_) {
//       _dialogIsOpen = false;
//     });
//   }
//
//   Future<void> _checkInternet() async {
//     bool hasInternet = await _hasInternet();
//
//     if (!mounted) return;
//
//     if (!hasInternet && !_dialogIsOpen) {
//       _showNoInternetDialog();
//     } else if (hasInternet && _dialogIsOpen) {
//       // dismiss the popup automatically when internet is back
//       if (Navigator.canPop(context)) {
//         Navigator.of(context, rootNavigator: true).pop();
//       }
//       _dialogIsOpen = false;
//     }
//   }
//
//
//   @override
//   void dispose() {
//     _subscription.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return widget.child;
//   }
// }
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
// // routes: {
// //   '/': (context) => const SplashScreen(),
// //   '/signup': (context) => const SignUpScreen(),
// //   '/login': (context) => const LoginScreen(),
// //   '/location': (context) => const LocationScreen(),
// //   '/payment': (context) {
// //     final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
// //     return PaymentScreen(bookingDetails: args);
// //   },
// // }
// //
// //
// // ,
//
//
//
//
// // -------------------------------------------------------------
// // Common styling
// // -------------------------------------------------------------
// class AppColors {
//   static const primary = Color(0xFF0066FF); // Electric Blue
//   static const accent = Color(0xFF32CD32); // Lime Green
//   static const bg = Color(0xFFF9FAFB);
//   static const text = Color(0xFF111827);
//   static const subtext = Color(0xFF6B7280);
//   static const card = Colors.white;
// }
//
// class AppGaps {
//   static const xs = SizedBox(height: 4);
//   static const sm = SizedBox(height: 8);
//   static const md = SizedBox(height: 12);
//   static const lg = SizedBox(height: 16);
//   static const xl = SizedBox(height: 24);
// }
//
// class AppButton extends StatelessWidget {
//   final String label;
//   final VoidCallback? onPressed;
//   final bool filled;
//
//   const AppButton({super.key, required this.label, this.onPressed, this.filled = true});
//
//   @override
//   Widget build(BuildContext context) {
//     final style = filled
//         ? ElevatedButton.styleFrom(
//       backgroundColor: AppColors.primary,
//       foregroundColor: Colors.white,
//       padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//     )
//         : OutlinedButton.styleFrom(
//       side: BorderSide(color: Theme.of(context).colorScheme.primary),
//       foregroundColor: Theme.of(context).colorScheme.primary,
//       padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//     );
//
//     final child = Text(label, style: const TextStyle(fontWeight: FontWeight.w600));
//     return filled
//         ? ElevatedButton(onPressed: onPressed, style: style, child: child)
//         : OutlinedButton(onPressed: onPressed, style: style, child: child);
//   }
// }
//
// class SectionCard extends StatelessWidget {
//   final Widget child;
//   const SectionCard({super.key, required this.child});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: AppColors.card,
//         borderRadius: BorderRadius.circular(18),
//         boxShadow: const [
//           BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4)),
//         ],
//       ),
//       padding: const EdgeInsets.all(16),
//       child: child,
//     );
//   }
// }








//
// import 'dart:async';
//
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'dart:io';
// import 'package:image_picker/image_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import 'auth/login.dart';
// import 'bottombar/Custombottombar.dart';
// import 'dashboard/admin_screen.dart';
// import 'dashboard/coach_screen.dart';
// import 'dashboard/security_screen.dart';
// import 'network.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:http/http.dart' as http;
// import 'package:timeago/timeago.dart' as timeago;
//
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   print('Handling a background message: ${message.messageId}');
// }
//
// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
// FlutterLocalNotificationsPlugin();
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   try {
//     await Firebase.initializeApp();
//
//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//     const AndroidNotificationChannel channel = AndroidNotificationChannel(
//       'high_importance_channel',
//       'High Importance Notifications',
//       description: 'This channel is used for important notifications.',
//       importance: Importance.high,
//     );
//
//     // Use the global instance only
//     await flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(channel);
//
//     await SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//     ]);
//
//     await ApiService.loadUserFromPrefs(); // make sure this is not blocking
//
//     final connectivityResult = await Connectivity().checkConnectivity();
//     print("🔌 Initial connectivity: $connectivityResult");
//   } catch (e, st) {
//     print("🔥 main() initialization error: $e\n$st");
//   }
//
//   runApp(const MyApp());
// }
//
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
//       ),
//
//       // ✅ Wrap ALL screens inside ConnectivityWrapper
//       builder: (context, child) {
//         return ConnectivityWrapper(
//           child: child ?? const SizedBox(), // fallback if child is null
//         );
//       },
//
//       // your starting screen
//       home: const SplashStep3(),
//     );
//   }
// }
import 'dart:async';
import 'core/utils/app_logger.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/login.dart';
import 'bottombar/Custombottombar.dart';
import 'bottombar/morescreen.dart';
import 'core/config/api_config.dart';
import 'core/navigation/role_router.dart';
import 'core/services/app_navigator.dart';
import 'core/services/permission_service.dart';
import 'core/services/session_manager.dart';
// The per-role dashboards are reached through `RoleRouter`, not imported here.
import 'network.dart';
import 'notification.dart';
import 'providers/profile_provider.dart';
import 'repositories/auth_repository.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

  // 🔹 Global notification plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // 🔹 Global navigator key for navigation from notification taps.
  // Shared with AppNavigator so the auth interceptor can route to Login when a
  // session expires.
  final GlobalKey<NavigatorState> navigatorKey = AppNavigator.key;

  // 🔹 Background message handler (must be top-level)
  Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    AppLogger.debug('📩 Handling background message: ${message.messageId}', name: 'main');
    _showLocalNotification(message);
  }

  // 🔹 Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title ?? 'Notification',
        notification.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'Used for important notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['screen'] ?? '',
      );
    }
  }

  // 🔹 Handle navigation from notification tap
  void _handleNotificationNavigation(RemoteMessage message) {
    final data = message.data;
    AppLogger.debug('📌 Navigating from notification: $data', name: 'main');

    // Example: route by 'screen' key from backend
    if (data['screen'] == 'notifications') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationsPage()),
      );
    } else {
      // Default route
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const CustomBottomNav()),
      );
    }
  }


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔐 Auth plumbing: let the API layer sign the user out when a refresh fails,
  // and warm up cached permissions so the first frame can already gate on them.
  SessionManager.instance.attach();
  await PermissionService.instance.loadFromCache();

  // Ensure Firebase initialized first
  await Firebase.initializeApp();
  // 🌐 Initialize connectivity
  Connectivity().onConnectivityChanged.listen((status) async {
    final hasNet = await InternetService.hasInternet();
    debugPrint(hasNet ? "✅ Internet Connected" : "❌ No Internet");
  });
  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// 🔔 Initialize local notifications (MISSING BEFORE)
  const AndroidInitializationSettings androidInit =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings darwinInit =
  DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  final InitializationSettings initSettings =
  InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
    macOS: darwinInit,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (response) {
      if (response.payload == 'booking') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
        );
      }
    },
  );


  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final userId = int.tryParse(await AuthService.getUserId() ?? '');

    if (userId != null) {
      await AuthRepository.instance.registerFcmToken(
        userId: userId,
        fcmToken: newToken,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    }
  });




  // Request permissions (Android 13+ & iOS)
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  AppLogger.debug("🔔 Permission: ${settings.authorizationStatus}", name: 'main');

  // Create notification channel BEFORE asking token
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((message) {
    AppLogger.debug("📩 Foreground message received", name: 'main');
    _showLocalNotification(message);
  });

  // Handle when clicking notification
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    AppLogger.debug("📌 Notification clicked", name: 'main');
    _handleNotificationNavigation(message);
  });

  // Get message when app was terminated
  RemoteMessage? initialMessage =
  await FirebaseMessaging.instance.getInitialMessage();

  // ---- 🔥 Get FCM Token (wrapped in try/catch) ---- //
  String? token;
  try {
    token = await FirebaseMessaging.instance.getToken();
    AppLogger.debug("📱 FCM Token: $token", name: 'main');
  } catch (e) {
    AppLogger.debug("❌ Failed to get FCM token: $e", name: 'main');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        // Single source of truth for the signed-in user. `bootstrap()` shows the
        // cached profile immediately, then reconciles with /auth/profile.
        // Eager (`lazy: false`) so the splash screen can await it before routing.
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => ProfileProvider()..bootstrap(),
        ),
      ],
      child: MyApp(initialMessage: initialMessage),
    ),
  );

}

class MyApp extends StatelessWidget {
  final RemoteMessage? initialMessage;
  const MyApp({super.key, this.initialMessage});

  @override
  Widget build(BuildContext context) {
    // Force portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Handle navigation if app launched from terminated state
    if (initialMessage != null) {
      Future.microtask(() => _handleNotificationNavigation(initialMessage!));
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: AppNavigator.messengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
        ),
        textTheme: GoogleFonts.dmSansTextTheme(),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const ConnectivityOverlay(), // ✅ global overlay
          ],
        );
      },
      home: const SplashStep3(),
    );
  }
}


// void main() async {
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//   // Notification channel for Android
//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'high_importance_channel',
//     'High Importance Notifications',
//     description: 'This channel is used for important notifications.',
//     importance: Importance.high,
//   );
//
//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//       AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);
//
//    // await Firebase.initializeApp();
//   // Force portrait mode
//   await SystemChrome.setPreferredOrientations([
//     DeviceOrientation.portraitUp,
//     DeviceOrientation.portraitDown,
//   ]);
//
//   // Initialize API service
//   await ApiService.loadUserFromPrefs();
//
//   // Initialize network status listener
//   final connectivityResult = await Connectivity().checkConnectivity();
//   print("🔌 Initial connectivity: $connectivityResult");
//
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF1A237E)),
//       ),
//       home: ConnectivityWrapper(child: const SplashStep3()), // ✅ Always start from Splash
//       // FutureBuilder<bool>(
//       //   future: ApiService.isLoggedIn(),
//       //   builder: (context, snapshot) {
//       //     if (snapshot.connectionState == ConnectionState.waiting) {
//       //       return const Scaffold(
//       //         body: Center(child: CircularProgressIndicator()),
//       //       );
//       //     } else if (snapshot.hasData && snapshot.data == true) {
//       //       return CustomBottomNav();
//       //     } else {
//       //       return const LoginScreen();
//       //     }
//       //   },
//       // ),
//     );
//   }
// }















// /// This widget controls the 3-step splash animation
// class SplashController extends StatefulWidget {
//   @override
//   State<SplashController> createState() => _SplashControllerState();
// }
//
// class _SplashControllerState extends State<SplashController> {
//   final PageController _pageController = PageController();
//   int _currentPage = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     // Auto animate between screens every 2 seconds
//     Timer.periodic(const Duration(seconds: 2), (timer) {
//       if (_currentPage < 2) {
//         _currentPage++;
//         _pageController.animateToPage(
//           _currentPage,
//           duration: const Duration(milliseconds: 600),
//           curve: Curves.easeInOut,
//         );
//       } else {
//         timer.cancel();
//         // Navigate to Login after splash
//         Future.delayed(const Duration(seconds: 1), () {
//           Navigator.pushReplacement(
//               context, MaterialPageRoute(builder: (_) => const LoginScreen()));
//         });
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: PageView(
//         controller: _pageController,
//         physics: const NeverScrollableScrollPhysics(), // disable swipe
//         children: const [
//           // SplashStep1(),
//           // SplashStep2(),
//           SplashStep3(),
//         ],
//       ),
//     );
//   }
// }
//
// /// Step 1 → Only Logo
// class SplashStep1 extends StatelessWidget {
//   const SplashStep1({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Image.asset(
//         "assets/ns.png", // Your NahataSports logo
//         height: 120,
//       ),
//     );
//   }
// }
//
// /// Step 2 → Logo with images around
// class SplashStep2 extends StatelessWidget {
//   const SplashStep2({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         Positioned(top: 80, left: 40, child: _splashImage("assets/ns1.jpg")),
//         Positioned(top: 80, right: 40, child: _splashImage("assets/ns2.jpg")),
//         Positioned(bottom: 100, left: 30, child: _splashImage("assets/ns3.jpg")),
//         Positioned(bottom: 100, right: 30, child: _splashImage("assets/ns4.jpg")),
//         Image.asset("assets/ns.png", height: 120),
//       ],
//     );
//   }
//
//   Widget _splashImage(String path) => ClipRRect(
//     borderRadius: BorderRadius.circular(12),
//     child: Image.asset(path, height: 90, width: 90, fit: BoxFit.cover),
//   );
// }

/// Step 3 → Logo + tagline + images

// //////////////////////////////////////////////////////////////
// class SplashStep3 extends StatefulWidget {
//   const SplashStep3({super.key});
//
//   @override
//   State<SplashStep3> createState() => _SplashStep3State();
// }
//
// class _SplashStep3State extends State<SplashStep3> {
//   final List<Timer> _timers = [];
//
//   double logoOpacity = 0.0;
//   double imagesOpacity = 0.0;
//   double text1Opacity = 0.0;
//   double text2Opacity = 0.0;
//   double text3Opacity = 0.0;
//
//   @override
//   void initState() {
//     super.initState();
//     _animateSplash();
//     _redirectAfterSplash();
//   }
//
//   void _animateSplash() {
//     // Animation sequence
//     Timer(const Duration(milliseconds: 500), () {
//       setState(() => logoOpacity = 1.0);
//     });
//     Timer(const Duration(milliseconds: 1500), () {
//       setState(() => imagesOpacity = 1.0);
//     });
//     Timer(const Duration(milliseconds: 2500), () {
//       setState(() => text1Opacity = 1.0);
//     });
//     Timer(const Duration(milliseconds: 3500), () {
//       setState(() => text2Opacity = 1.0);
//     });
//     Timer(const Duration(milliseconds: 4500), () {
//       setState(() => text3Opacity = 1.0);
//     });
//   }
//   Future<void> _redirectAfterSplash() async {
//     await Future.delayed(const Duration(seconds: 3));
//     final prefs = await SharedPreferences.getInstance();
//
//     final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
//     final bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
//     String? savedRole = prefs.getString('role');
//
//     // 🧩 Load user data in case it's available but role missing
//     await ApiService.loadUserFromPrefs();
//     final roleFromUser = ApiService.currentUser?['role']?.toString().toLowerCase();
//
//     // 🧠 Auto-fix missing role in prefs
//     if (savedRole == null && roleFromUser != null) {
//       print("🧩 Fixing missing role in SharedPreferences → $roleFromUser");
//       await prefs.setString('role', roleFromUser);
//       savedRole = roleFromUser;
//     }
//
//     if (isFirstLaunch) {
//       await prefs.setBool('isFirstLaunch', false);
//     }
//
//     print("🔹 Splash redirect check:");
//     print("   isLoggedIn: $isLoggedIn");
//     print("   savedRole: $savedRole");
//
//     Widget screen;
//
//     // ✅ CASE 1: Logged in and role known
//     if (isLoggedIn && savedRole != null) {
//       screen = _getScreenForRole(savedRole);
//     }
//     // ✅ CASE 2: Not logged in but role remembered (guest revisit)
//     else if (savedRole != null) {
//       screen = _getScreenForRole(savedRole);
//     }
//     // ✅ CASE 3: First-time or unknown role
//     else {
//       screen = const CustomBottomNav(); // default user home
//     }
//
//     if (mounted) {
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (_) => screen),
//             (route) => false,
//       );
//     }
//   }
//
//
//   @override
//   void dispose() {
//     // Cancel all pending timers to avoid calling setState after dispose
//     for (final timer in _timers) {
//       timer.cancel();
//     }
//     _timers.clear();
//     super.dispose();
//   }
//   // Future<void> _redirectAfterSplash() async {
//   //   await Future.delayed(const Duration(seconds: 3));
//   //   final prefs = await SharedPreferences.getInstance();
//   //
//   //   final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
//   //   final bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
//   //   final String? savedRole = prefs.getString('role'); // read saved role
//   //   final role = prefs.getString('role') ?? 'user';
//   //
//   //   Widget screen;
//   //
//   //
//   //   if (isFirstLaunch) {
//   //     // First time opening the app → mark as launched
//   //     await prefs.setBool('isFirstLaunch', false);
//   //   }
//   //   print("🔹 Splash redirect check:");
//   //   print("   isLoggedIn: $isLoggedIn");
//   //   print("   savedRole: $savedRole");
//   //   // ✅ CASE 1: User already logged in
//   //   if (isLoggedIn && savedRole != null) {
//   //     screen = _getScreenForRole(savedRole);
//   //   }
//   //   // ✅ CASE 2: Not logged in but role known (manually stored or remembered)
//   //   else if (savedRole != null) {
//   //     screen = _getScreenForRole(savedRole);
//   //   }
//   //   // ✅ CASE 3: Default (no role, not logged in)
//   //   else {
//   //     screen = const CustomBottomNav(); // or CustomBottomNav() if you want user home
//   //   }
//   //
//   //   if (mounted) {
//   //     Navigator.pushAndRemoveUntil(
//   //       context,
//   //       MaterialPageRoute(builder: (_) => screen),
//   //           (route) => false,
//   //     );
//   //   }
//   // }
//
//   /// Helper function to map role → correct screen
//   Widget _getScreenForRole(String role) {
//     switch (role.toLowerCase()) {
//       case 'admin':
//         return AdminDashboardScreen();
//       case 'coach':
//         return CoachHomeScreen();
//       case 'security':
//         return SecurityGateScannerScreen();
//       case 'student':
//       case 'user':
//       default:
//         return CustomBottomNav();
//     }
//   }
//
//   // Future<void> _redirectAfterSplash() async {
//   //   await Future.delayed(const Duration(seconds: 5));
//   //
//   //   SharedPreferences prefs = await SharedPreferences.getInstance();
//   //   final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
//   //
//   //   Widget screen;
//   //
//   //   if (isFirstLaunch) {
//   //     // First launch → show CustomBottomNav
//   //     prefs.setBool('isFirstLaunch', false);
//   //     screen = CustomBottomNav();
//   //   } else {
//   //     // Not first launch → redirect based on saved role
//   //     final savedRole = prefs.getString('role') ?? 'user';
//   //     switch (savedRole) {
//   //       case 'admin':
//   //         screen = AdminDashboardScreen();
//   //         break;
//   //       case 'coach':
//   //         screen = CoachDashboardScreen();
//   //         break;
//   //       case 'security':
//   //         screen = SecurityGateScannerScreen();
//   //         break;
//   //       default:
//   //         screen = CustomBottomNav();
//   //     }
//   //   }
//   //
//   //   if (mounted) {
//   //     Navigator.pushAndRemoveUntil(
//   //       context,
//   //       MaterialPageRoute(builder: (_) => screen),
//   //           (route) => false,
//   //     );
//   //   }
//   // }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Stack(
//         alignment: Alignment.center,
//         children: [
//           AnimatedOpacity(
//             opacity: imagesOpacity,
//             duration: const Duration(seconds: 1),
//             child: _buildOverlappingImages(),
//           ),
//           Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               AnimatedOpacity(
//                 opacity: logoOpacity,
//                 duration: const Duration(seconds: 1),
//                 child: Image.asset("assets/ns.png", height: 100),
//               ),
//               const SizedBox(height: 10),
//               _fadeText(text1Opacity, "Unleash Potential", 22, Colors.black),
//               _fadeText(text2Opacity, "Elevate Every Game.", 20, const Color(0xFF2E3192)),
//               _fadeText(text3Opacity, "Sport. Spirit. Strength. Success. Nahata.", 14, Colors.black54),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildOverlappingImages() {
//     return Stack(
//       children: [
//         // Top images
//         Positioned(top: 60, left: 20, child: _rotatedImage("assets/r1.png")),
//         Positioned(top: 60, left: 80, child: _rotatedImage("assets/r2.png")),
//         Positioned(top: 60, right: 90, child: _rotatedImage("assets/r3.png")),
//         Positioned(top: 60, right: 20, child: _rotatedImage("assets/r4.png")),
//         // Bottom images
//         Positioned(bottom: 80, left: 20, child: _rotatedImage("assets/r1.png")),
//         Positioned(bottom: 80, left: 80, child: _rotatedImage("assets/r2.png")),
//         Positioned(bottom: 80, right: 20, child: _rotatedImage("assets/r3.png")),
//         Positioned(bottom: 80, right: 80, child: _rotatedImage("assets/r4.png")),
//       ],
//     );
//   }
//
//   Widget _rotatedImage(String path) => Transform.rotate(
//     angle: -0.1,
//     child: _splashImage(path),
//   );
//
//   Widget _fadeText(double opacity, String text, double fontSize, Color color) {
//     return AnimatedOpacity(
//       opacity: opacity,
//       duration: const Duration(seconds: 1),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
//         decoration: BoxDecoration(
//           color: Colors.white.withOpacity(0.9),
//           borderRadius: BorderRadius.circular(25),
//         ),
//         child: Text(
//           text,
//           style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
//           textAlign: TextAlign.center,
//         ),
//       ),
//     );
//   }
//
//   Widget _splashImage(String path) => Container(
//     decoration: BoxDecoration(
//       borderRadius: BorderRadius.circular(16),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.2),
//           blurRadius: 10,
//           spreadRadius: 2,
//           offset: const Offset(3, 3),
//         ),
//       ],
//     ),
//     child: ClipRRect(
//       borderRadius: BorderRadius.circular(16),
//       child: Image.asset(
//         path,
//         height: 110,
//         width: 75,
//         fit: BoxFit.cover,
//       ),
//     ),
//   );
// }

////////////////////////////////////////////////////////////////


class SplashStep3 extends StatefulWidget {
  const SplashStep3({super.key});

  @override
  State<SplashStep3> createState() => _SplashStep3State();
}

class _SplashStep3State extends State<SplashStep3> {
  final List<Timer> _timers = [];

  double logoOpacity = 0.0;
  double imagesOpacity = 0.0;
  double text1Opacity = 0.0;
  double text2Opacity = 0.0;
  double text3Opacity = 0.0;

  @override
  void initState() {
    super.initState();
    _animateSplash();
    _redirectAfterSplash();
  }

  /// Utility: Safe setState (avoids calling after dispose)
  void safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _animateSplash() {
    // Store timers so they can be cancelled
    _timers.addAll([
      Timer(const Duration(milliseconds: 500), () => safeSetState(() => logoOpacity = 1.0)),
      Timer(const Duration(milliseconds: 1500), () => safeSetState(() => imagesOpacity = 1.0)),
      Timer(const Duration(milliseconds: 2500), () => safeSetState(() => text1Opacity = 1.0)),
      Timer(const Duration(milliseconds: 3500), () => safeSetState(() => text2Opacity = 1.0)),
      Timer(const Duration(milliseconds: 4500), () => safeSetState(() => text3Opacity = 1.0)),
    ]);
  }

  Future<void> _redirectAfterSplash() async {
    // Restore the session while the splash animation plays, so routing by role
    // uses live data instead of a stale preference.
    final sessionReady = _restoreSession();

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return; // prevent work after widget removed

    await sessionReady;
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    if (isFirstLaunch) await prefs.setBool('isFirstLaunch', false);

    final bool hasSession = await AuthRepository.instance.hasSession;

    // Prefer the role from the freshly loaded profile; fall back to the
    // persisted one when we are offline.
    String? savedRole = ApiService.currentProfile?.normalisedRole;
    if (savedRole == null || savedRole.isEmpty) {
      savedRole = prefs.getString('role')?.toLowerCase();
    } else {
      await prefs.setString('role', savedRole);
    }

    final role = savedRole;
    final routeToRole = hasSession && role != null && role.isNotEmpty;

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            routeToRole ? _getScreenForRole(role) : const CustomBottomNav(),
      ),
      (route) => false,
    );
  }

  /// App start-up: cached profile first (instant), then `/auth/profile` to
  /// pick up any server-side changes. A failure here is non-fatal — the cached
  /// profile keeps the app usable offline.
  Future<void> _restoreSession() async {
    try {
      await ApiService.loadUserFromPrefs();

      if (!await AuthRepository.instance.hasSession) return;

      final provider = ProfileProvider.maybeInstance;
      if (provider != null) {
        await provider.refresh(force: true);
      }

      // Re-sync the legacy `currentUser` map from whatever the refresh produced.
      await ApiService.loadUserFromPrefs();
    } catch (e) {
      debugPrint('Session restore failed: $e');
    }
  }

  /// Cancel all pending timers on dispose
  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  /// Re-entry after the splash: the same role → screen table the login screen
  /// uses, so a restored `COMPLEX_ADMIN` session reopens its own console.
  Widget _getScreenForRole(String role) => RoleRouter.screenFor(role);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            opacity: imagesOpacity,
            duration: const Duration(seconds: 1),
            child: _buildOverlappingImages(),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: logoOpacity,
                duration: const Duration(seconds: 1),
                child: Image.asset("assets/ns.png", height: 100),
              ),
              const SizedBox(height: 10),
              _fadeText(text1Opacity, "Unleash Potential", 22, Colors.black),
              _fadeText(text2Opacity, "Elevate Every Game.", 20, const Color(0xFF2E3192)),
              _fadeText(text3Opacity, "Sport. Spirit. Strength. Success. Nahata.", 14, Colors.black54),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverlappingImages() {
    return Stack(
      children: [
        Positioned(top: 60, left: 20, child: _rotatedImage("assets/r1.png")),
        Positioned(top: 60, left: 80, child: _rotatedImage("assets/r2.png")),
        Positioned(top: 60, right: 90, child: _rotatedImage("assets/r3.png")),
        Positioned(top: 60, right: 20, child: _rotatedImage("assets/r4.png")),
        Positioned(bottom: 80, left: 20, child: _rotatedImage("assets/r1.png")),
        Positioned(bottom: 80, left: 80, child: _rotatedImage("assets/r2.png")),
        Positioned(bottom: 80, right: 20, child: _rotatedImage("assets/r3.png")),
        Positioned(bottom: 80, right: 80, child: _rotatedImage("assets/r4.png")),
      ],
    );
  }

  Widget _rotatedImage(String path) => Transform.rotate(
    angle: -0.1,
    child: _splashImage(path),
  );

  Widget _fadeText(double opacity, String text, double fontSize, Color color) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(seconds: 1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _splashImage(String path) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          spreadRadius: 2,
          offset: const Offset(3, 3),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        path,
        height: 110,
        width: 75,
        fit: BoxFit.cover,
      ),
    ),
  );
}






class InternetService {
  /// How long a single reachability probe may take. Kept short: this decides
  /// whether a red banner covers the top of the app, so a slow answer is worse
  /// than a wrong one we correct a moment later.
  static const Duration _probeTimeout = Duration(seconds: 3);

  /// The probe target. Reaching *our* API is what "features are available"
  /// actually means — a working route to google.com says nothing about it.
  static final Uri _probeUri = Uri.parse(ApiConfig.baseUrl);

  /// True when the device has a network *and* our backend answers on it.
  ///
  /// Two deliberate choices, both of which the old google.com DNS lookup got
  /// wrong and which showed as a red banner on a healthy connection:
  ///
  ///  * `checkConnectivity()` returns a `List<ConnectivityResult>` (it has
  ///    since connectivity_plus 6). The previous code compared that list to
  ///    `ConnectivityResult.none`, which is never equal, so the fast offline
  ///    path never ran and every check paid for a DNS round-trip.
  ///  * A single failed probe is not proof of being offline. One dropped
  ///    packet on a handover, or a request issued before iOS has finished
  ///    bringing the interface up at launch, would flip the banner on. Only a
  ///    second consecutive failure counts.
  /// Swappable so tests can drive the state machine without a real socket.
  /// Production code never sets this.
  @visibleForTesting
  static Future<bool> Function()? probeOverride;

  static Future<bool> hasInternet() async {
    final results = await Connectivity().checkConnectivity();

    // No interface at all — no need to put a request on the wire.
    if (results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none)) {
      return false;
    }

    final probe = probeOverride ?? _reachable;
    if (await probe()) return true;

    // Give a flaky first attempt one more chance before crying offline.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return probe();
  }

  /// One probe. Any HTTP status counts as reachable — a 401 or 404 still
  /// proves the request travelled to the server and came back.
  static Future<bool> _reachable() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _probeTimeout;
      final request = await client.headUrl(_probeUri).timeout(_probeTimeout);
      request.followRedirects = false;
      final response = await request.close().timeout(_probeTimeout);
      await response.drain<void>();
      return true;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }
}



class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService _instance =
  ConnectivityService._internal();

  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller =
  StreamController<bool>.broadcast();

  Stream<bool> get connectivityStream => _controller.stream;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _controller.add(_isConnected(results));

    _connectivity.onConnectivityChanged.listen((results) {
      _controller.add(_isConnected(results));
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    // If ANY connection is available → online
    return results.any((result) => result != ConnectivityResult.none);
  }

  void dispose() {
    _controller.close();
  }
}

class ConnectivityProvider extends ChangeNotifier {
  /// Optimistic on purpose: the banner is a correction, not a greeting. It
  /// stays hidden until a check has actually failed.
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  late StreamSubscription _sub; // avoid strict generic to prevent cast issues
  Timer? _debounce; // small debounce to avoid flicker
  Timer? _recheck; // periodic poll, only while offline
  bool _checking = false; // one probe at a time

  /// How often to re-probe while the banner is up. Connectivity change events
  /// alone are not enough — a router that comes back on the same Wi-Fi network
  /// emits no event, and the banner would stay up for good.
  @visibleForTesting
  static Duration recheckInterval = const Duration(seconds: 10);

  ConnectivityProvider() {
    _check();
    // listen for connectivity changes (wifi/mobile/none)
    _sub = Connectivity().onConnectivityChanged.listen((_) => _handleChange());
  }

  void _handleChange() {
    // debounce rapid flaps
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _check);
  }

  Future<void> retryNow() => _check();

  /// Probes once, ignoring the call if a probe is already in flight so the
  /// timer and a user's RETRY tap cannot stack up.
  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      _updateState(await InternetService.hasInternet());
    } finally {
      _checking = false;
    }
  }

  void _updateState(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;

    // Poll only while we believe we are offline; stop as soon as we recover.
    _recheck?.cancel();
    if (!online) {
      _recheck = Timer.periodic(recheckInterval, (_) => _check());
    } else {
      _recheck = null;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    _debounce?.cancel();
    _recheck?.cancel();
    super.dispose();
  }
}

class ConnectivityOverlay extends StatefulWidget {
  const ConnectivityOverlay({super.key});

  @override
  State<ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<ConnectivityOverlay>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConnectivityProvider>(context);
    final isOnline = provider.isOnline;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 350),
        offset: isOnline ? const Offset(0, -1) : Offset.zero,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              color: isOnline ? Colors.green[600] : Colors.red[600],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOnline ? 'Back online' : 'No internet connection',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOnline
                                ? 'You are connected. Sync resumed.'
                                : 'Some features may be unavailable. Check your connection.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isOnline) ...[
                      TextButton(
                        onPressed: () async {
                          await provider.retryNow();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('RETRY'),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//
//   // 🔹 Request notification permission (important for Android 13+ & iOS)
//   NotificationSettings settings =
//   await FirebaseMessaging.instance.requestPermission(
//     alert: true,
//     badge: true,
//     sound: true,
//   );
//   print('🔔 Permission status: ${settings.authorizationStatus}');
//
//   // 🔹 Get FCM token (for backend use)
//   String? token = await FirebaseMessaging.instance.getToken();
//   print('📱 FCM Token: $token');
//
//   // 🔹 Setup background message handler
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//   // 🔹 Android notification channel setup
//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'high_importance_channel',
//     'High Importance Notifications',
//     description: 'Used for important notifications',
//     importance: Importance.high,
//   );
//
//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//       AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);
//
//   // 🔹 Foreground listener
//   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//     print('📩 Foreground message: ${message.messageId}');
//     _showLocalNotification(message);
//   });
//
//   // 🔹 Notification click while app in background
//   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//     print('📌 Notification clicked (background): ${message.data}');
//     _handleNotificationNavigation(message);
//   });
//
//   // 🔹 Handle terminated state (app killed)
//   RemoteMessage? initialMessage =
//   await FirebaseMessaging.instance.getInitialMessage();
//   print('🚀 Initial message (terminated): $initialMessage');
//
//   runApp(MyApp(initialMessage: initialMessage));
// }