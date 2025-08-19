// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:staff_mate/pages/welcome_page.dart'; // Import your welcome page

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();

//     // Delay for 2 seconds before navigating to WelcomePage
//     Timer(const Duration(seconds: 2), () {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const WelcomePage()),
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Image.asset(
//           'assets/images/logo.png',
//           width: 150,
//           height: 150,
//         ),
//       ),
//     );
//   }
// }
