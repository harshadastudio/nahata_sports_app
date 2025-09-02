

import 'package:flutter/material.dart';

import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController controller = PageController();
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _obPage(Icons.flash_on, 'Book your favorite sport in seconds',
          'Pick a venue, choose a slot, and you’re done.'),
      _obPage(Icons.calendar_month, 'Check slot availability & pay online',
          'Transparent pricing and instant confirmation.'),
      _obPage(Icons.sports_handball, 'Enjoy a seamless sports experience',
          'Friendly venues, great coaches, inclusive access.'),
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
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
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
                              ? const Color(0xFF0A198D)
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A198D),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      if (index == pages.length - 1) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      } else {
                        controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                        );
                      }
                    },
                    child: Text(
                        index == pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(color: Colors.white)),
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
          Icon(icon, size: 96, color: const Color(0xFF0A198D)),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
