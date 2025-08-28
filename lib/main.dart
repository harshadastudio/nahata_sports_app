// import 'package:flutter/material.dart';
// import 'package:nahata_app/screens/location_screen.dart';
// import 'package:nahata_app/screens/login_screen.dart';
// import 'package:nahata_app/screens/payment_screen.dart';
// import 'package:nahata_app/screens/registration.dart';
// import 'package:nahata_app/splash_screen.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return  MaterialApp(
//       title: 'Nahata Sports Booking',
//       theme: ThemeData(
//         primarySwatch: Colors.indigo,
//       ),
//       debugShowCheckedModeBanner: false,
//
//       initialRoute: '/',
//       routes: {
//         '/': (context) => const SplashScreen(),
//         '/signup': (context) => const SignUpScreen(),
//         // '/login': (context) => const LoginScreen(),
//           '/login': (context) => const LoginScreen(),
//           '/location': (context) => const LocationScreen(),
//             '/payment': (context) {
//               final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
//               return PaymentScreen(bookingDetails: args);
//             },
//       },
//     );
//   }
// }




import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nahata_app/screens/location_screen.dart';
import 'package:nahata_app/screens/login_screen.dart';
import 'package:nahata_app/screens/payment_screen.dart';
import 'package:nahata_app/screens/registration.dart';
import 'package:nahata_app/splash_screen.dart';

import 'dashboard/dashboard_screen.dart';
import 'dashboard/students_parents.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return InternetCheckWrapper(
      child: MaterialApp(
        title: 'Nahata Sports Booking',
        theme: ThemeData( primarySwatch: Colors.indigo, ),
        // theme: ThemeData(
        //   brightness: Brightness.light,
        //   primarySwatch: Colors.indigo,
        //   scaffoldBackgroundColor: Colors.white,
        //   appBarTheme: const AppBarTheme(
        //     backgroundColor: Colors.indigo,
        //     foregroundColor: Colors.white,
        //   ),
        // ),
        //
        // // Dark theme
        // darkTheme: ThemeData(
        //   brightness: Brightness.dark,
        //   primarySwatch: Colors.indigo,
        //   scaffoldBackgroundColor: Colors.black,
        //   appBarTheme: const AppBarTheme(
        //     backgroundColor: Colors.black,
        //     foregroundColor: Colors.white,
        //   ),
        // ),
        // themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',

        routes: {
          '/': (context) => const InternetCheckWrapper(child: SplashScreen()),
          '/signup': (context) => InternetCheckWrapper(child: SignUpScreen()),
          '/login': (context) => const InternetCheckWrapper(child: LoginScreen()),
          '/location': (context) => const InternetCheckWrapper(child: LocationScreen()),
          // '/dashboard': (context) => const InternetCheckWrapper(child: DashboardScreen()),
          '/students_parents': (context) => const InternetCheckWrapper(child: StudentsParentsScreen()),
          // '/roleselection': (context) => const InternetCheckWrapper(child: RoleSelectionScreen()),
          '/payment': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return InternetCheckWrapper(
              child: PaymentScreen(bookingDetails: args),
            );
          },
        },
      ),
    );
  }
}

// /// ✅ InternetCheckWrapper monitors connectivity and shows popup if offline
// class InternetCheckWrapper extends StatefulWidget {
//   final Widget child;
//   const InternetCheckWrapper({super.key, required this.child});
//
//   @override
//   State<InternetCheckWrapper> createState() => _InternetCheckWrapperState();
// }
//
// class _InternetCheckWrapperState extends State<InternetCheckWrapper> {
//   late final _subscription;
//   bool _dialogIsOpen = false;
//   BuildContext? _dialogContext;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkInternet();
//     });
//
//     // Listen to connectivity changes
//     _subscription = Connectivity().onConnectivityChanged.listen((_) {
//       _checkInternet();
//     });
//   }
//
//   Future<void> _checkInternet() async {
//     bool hasInternet = await _hasInternet();
//
//     if (!hasInternet && !_dialogIsOpen) {
//       _showNoInternetDialog();
//     } else if (hasInternet && _dialogIsOpen && _dialogContext != null) {
//       Navigator.pop(_dialogContext!); // close dialog automatically
//       _dialogIsOpen = false;
//       _dialogContext = null;
//     }
//   }
//
//   Future<bool> _hasInternet() async {
//     try {
//       final result = await InternetAddress.lookup('example.com');
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } on SocketException catch (_) {
//       return false;
//     }
//   }
//
//   void _showNoInternetDialog() {
//     _dialogIsOpen = true;
//
//   //   showDialog(
//   //     context: context,
//   //     barrierDismissible: false,
//   //     builder: (dialogContext) {
//   //       _dialogContext = dialogContext;
//   //       return const AlertDialog(
//   //         title: Text("No Internet"),
//   //         content: Text("Please check your internet connection."),
//   //       );
//   //     },
//   //   ).then((_) {
//   //     _dialogIsOpen = false;
//   //     _dialogContext = null;
//   //   });
//   // }
//
//
//     showDialog(
//       context: context,
//       barrierDismissible: false, // cannot dismiss by tapping outside
//       builder: (context) => WillPopScope(
//         // prevent back button closing
//         onWillPop: () async => false,
//         child: AlertDialog(
//           title: const Text("No Internet"),
//           content: const Text("Please check your internet connection."),
//           actions: [
//             TextButton(
//               onPressed: () async {
//                 bool hasInternet = await _hasInternet();
//                 if (hasInternet) {
//                   Navigator.of(context, rootNavigator: true).pop();
//                   _dialogIsOpen = false;
//                 }
//                 // if no internet → keep dialog open
//               },
//               child: const Text("Retry"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
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


class InternetCheckWrapper extends StatefulWidget {
  final Widget child;
  const InternetCheckWrapper({super.key, required this.child});

  @override
  State<InternetCheckWrapper> createState() => _InternetCheckWrapperState();
}

class _InternetCheckWrapperState extends State<InternetCheckWrapper> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _dialogIsOpen = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInternet();
    });

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      // results is List<ConnectivityResult>
      _checkInternet();
    });
  }

  // Future<void> _checkInternet() async {
  //   bool hasInternet = await _hasInternet();
  //
  //   if (!mounted) return; // widget not ready
  //
  //   if (!hasInternet && !_dialogIsOpen) {
  //     _showNoInternetDialog();
  //   } else if (hasInternet && _dialogIsOpen) {
  //     // Ensure navigator is ready before popping
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       if (mounted) {
  //         Navigator.of(context, rootNavigator: true).pop();
  //         _dialogIsOpen = false;
  //       }
  //     });
  //   }
  // }

  // Future<void> _checkInternet() async {
  //   bool hasInternet = await _hasInternet();
  //
  //   if (!hasInternet && !_dialogIsOpen) {
  //     _showNoInternetDialog();
  //   } else if (hasInternet && _dialogIsOpen) {
  //     // Internet restored → close popup automatically
  //     Navigator.of(context, rootNavigator: true).pop();
  //     _dialogIsOpen = false;
  //   }
  // }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
  //
  // void _showNoInternetDialog() {
  //   _dialogIsOpen = true;
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false, // cannot dismiss manually
  //     builder: (context) => WillPopScope(
  //       onWillPop: () async => false, // disable back button
  //       child: const AlertDialog(
  //         title: Text("No Internet"),
  //         content: Text("Please check your internet connection."),
  //       ),
  //     ),
  //   ).then((_) {
  //     _dialogIsOpen = false;
  //   });
  // }




  void _showNoInternetDialog() {
    _dialogIsOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("No Internet"),
        content: const Text("Please check your internet connection."),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop(); // close dialog
              _dialogIsOpen = false;
              _checkInternet(); // retry check
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    ).then((_) {
      _dialogIsOpen = false;
    });
  }

  Future<void> _checkInternet() async {
    bool hasInternet = await _hasInternet();

    if (!mounted) return;

    if (!hasInternet && !_dialogIsOpen) {
      _showNoInternetDialog();
    } else if (hasInternet && _dialogIsOpen) {
      // dismiss the popup automatically when internet is back
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _dialogIsOpen = false;
    }
  }


  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}



























// routes: {
//   '/': (context) => const SplashScreen(),
//   '/signup': (context) => const SignUpScreen(),
//   '/login': (context) => const LoginScreen(),
//   '/location': (context) => const LocationScreen(),
//   '/payment': (context) {
//     final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
//     return PaymentScreen(bookingDetails: args);
//   },
// },