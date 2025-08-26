// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'dart:async';
//
// import 'package:nahata_app/services/api_service.dart';
//
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});
//
//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   double _opacity = 0.0;
//   double _scale = 0.8;
//
//   @override
//   @override
//   void initState() {
//     super.initState();
//
//     Timer(const Duration(seconds: 2), () async {
//       final isLoggedIn = await ApiService.isLoggedIn();
//
//       if (!mounted) return; // ✅ Prevents navigation if widget is disposed
//
//       Navigator.pushReplacementNamed(
//         context,
//         isLoggedIn ? '/location' : '/login',
//       );
//     });
//   }
//
//   // void initState() {
//   //   super.initState();
//   //
//   //   // Lock orientation to portrait while splash is visible
//   //   SystemChrome.setPreferredOrientations([
//   //     DeviceOrientation.portraitUp,
//   //   ]);
//   //
//   //   // Start animation shortly after frame renders
//   //   Future.delayed(const Duration(milliseconds: 100), () {
//   //     setState(() {
//   //       _opacity = 1.0;
//   //       _scale = 1.0;
//   //     });
//   //   });
//   //
//   //   // Navigate after delay
//   //   Timer(const Duration(seconds: 3), () {
//   //     // Reset orientation
//   //     SystemChrome.setPreferredOrientations(DeviceOrientation.values);
//   //     Navigator.pushReplacementNamed(context, '/');
//   //   });
//   // }
//
//   Future<void> _checkLoginStatus() async {
//     await Future.delayed(const Duration(seconds: 2)); // optional loading
//     bool isLoggedIn = await ApiService.isLoggedIn(); // check stored login
//
//     if (isLoggedIn) {
//       Navigator.pushReplacementNamed(context, '/location');
//     } else {
//       Navigator.pushReplacementNamed(context, '/login');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: AnimatedOpacity(
//           duration: const Duration(milliseconds: 800),
//           opacity: _opacity,
//           child: AnimatedScale(
//             scale: _scale,
//             duration: const Duration(milliseconds: 800),
//             curve: Curves.easeOutBack,
//             child: Image.asset(
//               'assets/images/nahata.png',
//
//               fit: BoxFit.contain,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }



import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;
  double _scale = 0.8;

  @override
  void initState() {
    super.initState();

    // Start animation
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _opacity = 1.0;
        _scale = 1.0;
      });
    });

    // After delay, navigate to signup screen
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/signup');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 800),
          opacity: _opacity,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            child: Image.asset(
              'assets/images/nahata.webp',
              height: 300,
            ),
          ),
        ),
      ),
    );
  }
}
