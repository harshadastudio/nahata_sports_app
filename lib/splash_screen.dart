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

//
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nahata_app/screens/login_screen.dart';
import 'package:nahata_app/screens/regi.dart';

import 'dart:async';
import 'package:flutter/material.dart';


import 'dart:async';
import 'package:flutter/material.dart';


// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});
//
//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen>
//     with TickerProviderStateMixin {
//   late AnimationController _logoController;
//   late Animation<double> _logoAnimation;
//
//   late AnimationController _textController;
//   late Animation<double> _textAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Logo bounce animation
//     _logoController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1000),
//     );
//     _logoAnimation = CurvedAnimation(
//       parent: _logoController,
//       curve: Curves.elasticOut,
//     );
//     _logoController.forward();
//
//     // Text fade-in animation
//     _textController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1200),
//     );
//     _textAnimation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(parent: _textController, curve: Curves.easeIn),
//     );
//
//     // Delay text animation slightly after logo
//     Future.delayed(const Duration(milliseconds: 600), () {
//       _textController.forward();
//     });
//
//     // Navigate after delay
//     Future.delayed(const Duration(seconds: 3), () {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const LoginScreen()),
//       );
//     });
//   }
//
//   @override
//   void dispose() {
//     _logoController.dispose();
//     _textController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: AnimatedContainer(
//         duration: const Duration(seconds: 3),
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF0A198D), Color(0xFF0A5FD9)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               ScaleTransition(
//                 scale: _logoAnimation,
//                 child: Image.asset(
//                   'assets/images/3.webp',
//                   height: 120,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               FadeTransition(
//                 opacity: _textAnimation,
//                 child: const Text(
//                   "Book your game, anytime!",
//                   style: TextStyle(
//                     fontSize: 18,
//                     color: Colors.white,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 40),
//               const CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }







// import 'package:flutter/material.dart';
//
//
// class SplashScreen extends StatefulWidget {
//   // static const routeName = '/';
//   const SplashScreen({super.key});
//
//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
//   double _opacity = 0;
//   late final AnimationController _controller;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
//     Future.delayed(const Duration(milliseconds: 50), () {
//       if (mounted) {
//         _controller.forward();
//         setState(() => _opacity = 1);
//       }
//     });
//
//     // Navigate after 1.6s to onboarding (safe check mounted)
//     Future.delayed(const Duration(milliseconds: 1600), () {
//       if (mounted) {
//         Navigator.pushReplacementNamed(context, OnboardingScreen.routeName);
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Responsive sizing
//     final media = MediaQuery.of(context);
//     final logoSize = (media.size.shortestSide * 0.30).clamp(80.0, 220.0);
//
//     return Scaffold(
//       body: Container(
//         width: double.infinity,
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(colors: [Color(0xFF0066FF), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
//         ),
//         child: SafeArea(
//           child: Center(
//             child: AnimatedOpacity(
//               duration: const Duration(milliseconds: 700),
//               opacity: _opacity,
//               child: ScaleTransition(
//                 scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.sports_soccer, color: Colors.white, size: logoSize),
//                     const SizedBox(height: 14),
//                     const Text('Nahata Sports', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
//                     const SizedBox(height: 6),
//                     const Text('Play. Book. Repeat.', style: TextStyle(color: Colors.white70)),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//









class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  double _opacity = 0.0;
  double _scale = 0.95; // slight zoom in effect

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

    // Navigate to Home after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedOpacity(
        duration: const Duration(seconds: 2),
        opacity: _opacity,
        child: AnimatedScale(
          duration: const Duration(seconds: 2),
          scale: _scale,
          child: SizedBox.expand(
            child: Image.asset(
              'assets/images/3.webp', // your single image
              fit: BoxFit.cover, // fills the screen
            ),
          ),
        ),
      ),
    );
  }
}










class AppColors {
  static const Color primary = Color(0xFF1565C0); // Blue
  static const Color subtext = Colors.black54;    // Gray text
}

class OnboardingScreen extends StatefulWidget {
  static const routeName = '/onboarding';
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _obPage(
        Icons.flash_on,
        'Book your favorite sport in seconds',
        'Pick a venue, choose a slot, and you’re done.',
      ),
      _obPage(
        Icons.calendar_month,
        'Check slot availability & pay online',
        'Transparent pricing and instant confirmation.',
      ),
      _obPage(
        Icons.sports_handball,
        'Enjoy a seamless sports experience',
        'Friendly venues, great coaches, inclusive access.',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: controller,
                onPageChanged: (i) => setState(() => index = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // Dot indicators
                  Row(
                    children: List.generate(
                      pages.length,
                          (i) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == index
                              ? AppColors.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Next / Get Started button
                  AppButton(
                    label: index == pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    onPressed: () {
                      if (index == pages.length - 1) {
                        // Navigator.pushReplacementNamed(
                        //   context,
                        //   LoginScreen.route,
                        // );
                      } else {
                        controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _obPage(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 96, color: AppColors.primary),
          AppGaps.xl,
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppGaps.md,
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}
class AppGaps {
  static const SizedBox xs = SizedBox(height: 4, width: 4);
  static const SizedBox sm = SizedBox(height: 8, width: 8);
  static const SizedBox md = SizedBox(height: 16, width: 16);
  static const SizedBox lg = SizedBox(height: 24, width: 24);
  static const SizedBox xl = SizedBox(height: 32, width: 32);
}





class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final double height;
  final double radius;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.height = 48,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? AppColors.primary : Colors.white,
          foregroundColor: filled ? Colors.white : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: AppColors.primary,
              width: filled ? 0 : 2,
            ),
          ),
          elevation: filled ? 2 : 0,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}













































