// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:pinput/pinput.dart';
// import 'package:staff_mate/pages/login_page.dart';
// import 'package:staff_mate/services/otp_service.dart';

// // Reuse AppColors from your existing code
// class OTPEmailPage extends StatefulWidget {
//   const OTPEmailPage({super.key});

//   @override
//   State<OTPEmailPage> createState() => _OTPEmailPageState();
// }

// class _OTPEmailPageState extends State<OTPEmailPage> {
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _otpController = TextEditingController();
//   final FocusNode _pinFocusNode = FocusNode();
  
//   bool _isLoading = false;
//   bool _isOTPSent = false;
//   bool _isResendEnabled = true;
//   int _resendTimer = 30;
//   Timer? _timer;
  
//   String _verificationId = '';
//   String _userEmail = '';

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _otpController.dispose();
//     _pinFocusNode.dispose();
//     _timer?.cancel();
//     super.dispose();
//   }

//   void _startResendTimer() {
//     setState(() {
//       _isResendEnabled = false;
//       _resendTimer = 30;
//     });
    
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_resendTimer > 0) {
//         setState(() => _resendTimer--);
//       } else {
//         setState(() => _isResendEnabled = true);
//         timer.cancel();
//       }
//     });
//   }

//   Future<void> _sendOTP() async {
//     if (_emailController.text.trim().isEmpty) {
//       _showSnackBar('Please enter your email', Colors.red);
//       return;
//     }

//     if (!_isValidEmail(_emailController.text.trim())) {
//       _showSnackBar('Please enter a valid email', Colors.red);
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       // Call your OTP send API
//       final response = await OTPService.sendEmailOTP(
//         email: _emailController.text.trim(),
//       );

//       if (response['success'] == true) {
//         setState(() {
//           _isOTPSent = true;
//           _userEmail = _emailController.text.trim();
//           _verificationId = response['verificationId'] ?? '';
//         });
        
//         _startResendTimer();
//         _showSnackBar('OTP sent to your email', Colors.green);
        
//         // Auto-focus OTP field
//         Future.delayed(const Duration(milliseconds: 300), () {
//           FocusScope.of(context).requestFocus(_pinFocusNode);
//         });
//       } else {
//         _showSnackBar('Failed to send OTP', Colors.red);
//       }
//     } catch (e) {
//       _showSnackBar('Error: ${e.toString()}', Colors.red);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _verifyOTP() async {
//     if (_otpController.text.trim().isEmpty) {
//       _showSnackBar('Please enter OTP', Colors.red);
//       return;
//     }

//     if (_otpController.text.trim().length < 6) {
//       _showSnackBar('Please enter valid 6-digit OTP', Colors.red);
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       final isValid = await OTPService.verifyEmailOTP(
//         email: _userEmail,
//         otp: _otpController.text.trim(),
//         verificationId: _verificationId,
//       );

//       if (isValid) {
//         // OTP verified - navigate to login page
//         _showSnackBar('Email verified successfully!', Colors.green);
        
//         Future.delayed(const Duration(milliseconds: 500), () {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => LoginPage(
//                 verifiedEmail: _userEmail,
//               ),
//             ),
//           );
//         });
//       } else {
//         _showSnackBar('Invalid OTP', Colors.red);
//       }
//     } catch (e) {
//       _showSnackBar('Verification failed: ${e.toString()}', Colors.red);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _resendOTP() async {
//     if (!_isResendEnabled) return;

//     setState(() => _isLoading = true);

//     try {
//       final response = await OTPService.sendEmailOTP(
//         email: _userEmail,
//       );

//       if (response['success'] == true) {
//         _startResendTimer();
//         _showSnackBar('OTP resent successfully', Colors.green);
//       } else {
//         _showSnackBar('Failed to resend OTP', Colors.red);
//       }
//     } catch (e) {
//       _showSnackBar('Error: ${e.toString()}', Colors.red);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   bool _isValidEmail(String email) {
//     return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
//   }

//   void _showSnackBar(String message, Color color) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final Size size = MediaQuery.of(context).size;
//     final EdgeInsets padding = MediaQuery.of(context).padding;

//     return Scaffold(
//       backgroundColor: AppColors.primaryDarkBlue,
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         systemOverlayStyle: const SystemUiOverlayStyle(
//           statusBarColor: Colors.transparent,
//           statusBarIconBrightness: Brightness.light,
//         ),
//       ),
//       body: Stack(
//         children: [
//           // Background Decor
//           Positioned(
//             top: -size.width * 0.2,
//             right: -size.width * 0.2,
//             child: Container(
//               width: size.width * 0.8,
//               height: size.width * 0.8,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.white.withOpacity(0.05),
//               ),
//             ),
//           ),

//           Column(
//             children: [
//               // Top Section
//               Expanded(
//                 flex: 4,
//                 child: SafeArea(
//                   child: Center(
//                     child: AnimationLimiter(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: AnimationConfiguration.toStaggeredList(
//                           duration: const Duration(milliseconds: 600),
//                           childAnimationBuilder: (widget) => ScaleAnimation(
//                             child: FadeInAnimation(child: widget),
//                           ),
//                           children: [
//                             Container(
//                               padding: EdgeInsets.all(size.width * 0.06),
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 color: Colors.white.withOpacity(0.1),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.black.withOpacity(0.1),
//                                     blurRadius: 20,
//                                     spreadRadius: 5,
//                                   ),
//                                 ],
//                               ),
//                               child: Icon(
//                                 _isOTPSent ? Icons.mark_email_read_rounded : Icons.email_rounded,
//                                 size: size.width * 0.18,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             const SizedBox(height: 20),
//                             Text(
//                               _isOTPSent ? 'Verify Email' : 'Welcome',
//                               style: GoogleFonts.poppins(
//                                 fontSize: size.width * 0.065,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),

//               // Bottom Sheet
//               Expanded(
//                 flex: 5,
//                 child: Container(
//                   width: double.infinity,
//                   decoration: const BoxDecoration(
//                     color: AppColors.bgGrey,
//                     borderRadius: BorderRadius.only(
//                       topLeft: Radius.circular(30),
//                       topRight: Radius.circular(30),
//                     ),
//                   ),
//                   child: ClipRRect(
//                     borderRadius: const BorderRadius.only(
//                       topLeft: Radius.circular(30),
//                       topRight: Radius.circular(30),
//                     ),
//                     child: SingleChildScrollView(
//                       physics: const BouncingScrollPhysics(),
//                       child: Padding(
//                         padding: EdgeInsets.fromLTRB(30, 40, 30, 30 + padding.bottom),
//                         child: AnimationLimiter(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.center,
//                             children: AnimationConfiguration.toStaggeredList(
//                               duration: const Duration(milliseconds: 600),
//                               childAnimationBuilder: (widget) => SlideAnimation(
//                                 verticalOffset: 50.0,
//                                 child: FadeInAnimation(child: widget),
//                               ),
//                               children: [
//                                 // Handle bar
//                                 Container(
//                                   width: 40,
//                                   height: 4,
//                                   margin: const EdgeInsets.only(bottom: 25),
//                                   decoration: BoxDecoration(
//                                     color: Colors.grey[300],
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                 ),

//                                 if (!_isOTPSent) ...[
//                                   // Email Input Screen
//                                   Text(
//                                     'Enter Your Email',
//                                     style: GoogleFonts.poppins(
//                                       fontSize: size.width * 0.06,
//                                       fontWeight: FontWeight.bold,
//                                       color: AppColors.textDark,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     'We\'ll send a verification code to your email',
//                                     textAlign: TextAlign.center,
//                                     style: GoogleFonts.poppins(
//                                       fontSize: size.width * 0.035,
//                                       color: AppColors.textBodyColor,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 30),

//                                   // Email Field
//                                   Container(
//                                     decoration: BoxDecoration(
//                                       color: Colors.white,
//                                       borderRadius: BorderRadius.circular(16),
//                                       boxShadow: [
//                                         BoxShadow(
//                                           color: Colors.grey.withOpacity(0.1),
//                                           blurRadius: 10,
//                                           offset: const Offset(0, 5),
//                                         ),
//                                       ],
//                                     ),
//                                     child: TextField(
//                                       controller: _emailController,
//                                       keyboardType: TextInputType.emailAddress,
//                                       style: GoogleFonts.poppins(
//                                         color: AppColors.textDark,
//                                         fontSize: 15,
//                                       ),
//                                       decoration: InputDecoration(
//                                         hintText: 'Email Address',
//                                         hintStyle: GoogleFonts.poppins(
//                                           color: Colors.grey.shade400,
//                                           fontSize: 14,
//                                         ),
//                                         prefixIcon: Icon(
//                                           Icons.email_outlined,
//                                           color: AppColors.primaryDarkBlue.withOpacity(0.7),
//                                           size: 22,
//                                         ),
//                                         border: OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(16),
//                                           borderSide: BorderSide.none,
//                                         ),
//                                         filled: true,
//                                         fillColor: Colors.transparent,
//                                         contentPadding: const EdgeInsets.symmetric(
//                                           vertical: 18,
//                                           horizontal: 20,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(height: 20),

//                                   // Send OTP Button
//                                   _buildActionButton(
//                                     onPressed: _sendOTP,
//                                     text: 'Send OTP',
//                                     icon: Icons.send_rounded,
//                                   ),
//                                 ] else ...[
//                                   // OTP Verification Screen
//                                   Text(
//                                     'Verification Code',
//                                     style: GoogleFonts.poppins(
//                                       fontSize: size.width * 0.06,
//                                       fontWeight: FontWeight.bold,
//                                       color: AppColors.textDark,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     'Enter the 6-digit code sent to',
//                                     style: GoogleFonts.poppins(
//                                       fontSize: size.width * 0.035,
//                                       color: AppColors.textBodyColor,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 16,
//                                       vertical: 8,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: AppColors.primaryDarkBlue.withOpacity(0.1),
//                                       borderRadius: BorderRadius.circular(20),
//                                     ),
//                                     child: Text(
//                                       _userEmail,
//                                       style: GoogleFonts.poppins(
//                                         fontSize: size.width * 0.04,
//                                         fontWeight: FontWeight.w600,
//                                         color: AppColors.primaryDarkBlue,
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(height: 30),

//                                   // OTP Input
//                                   Pinput(
//                                     controller: _otpController,
//                                     focusNode: _pinFocusNode,
//                                     length: 6,
//                                     defaultPinTheme: PinTheme(
//                                       width: 50,
//                                       height: 55,
//                                       textStyle: GoogleFonts.poppins(
//                                         fontSize: 22,
//                                         fontWeight: FontWeight.w600,
//                                         color: AppColors.primaryDarkBlue,
//                                       ),
//                                       decoration: BoxDecoration(
//                                         color: Colors.white,
//                                         borderRadius: BorderRadius.circular(12),
//                                         border: Border.all(
//                                           color: Colors.grey.shade300,
//                                           width: 1,
//                                         ),
//                                       ),
//                                     ),
//                                     focusedPinTheme: PinTheme(
//                                       width: 50,
//                                       height: 55,
//                                       textStyle: GoogleFonts.poppins(
//                                         fontSize: 22,
//                                         fontWeight: FontWeight.w600,
//                                         color: AppColors.primaryDarkBlue,
//                                       ),
//                                       decoration: BoxDecoration(
//                                         color: Colors.white,
//                                         borderRadius: BorderRadius.circular(12),
//                                         border: Border.all(
//                                           color: AppColors.primaryDarkBlue,
//                                           width: 2,
//                                         ),
//                                       ),
//                                     ),
//                                     onCompleted: (pin) {
//                                       _verifyOTP();
//                                     },
//                                   ),
//                                   const SizedBox(height: 20),

//                                   // Verify Button
//                                   _buildActionButton(
//                                     onPressed: _verifyOTP,
//                                     text: 'Verify & Continue',
//                                     icon: Icons.verified_rounded,
//                                   ),
//                                   const SizedBox(height: 16),

//                                   // Resend Option
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Text(
//                                         "Didn't receive code? ",
//                                         style: GoogleFonts.poppins(
//                                           color: AppColors.textBodyColor,
//                                           fontSize: 14,
//                                         ),
//                                       ),
//                                       GestureDetector(
//                                         onTap: _isResendEnabled ? _resendOTP : null,
//                                         child: Text(
//                                           _isResendEnabled
//                                               ? "Resend"
//                                               : "Resend in $_resendTimer sec",
//                                           style: GoogleFonts.poppins(
//                                             color: _isResendEnabled
//                                                 ? AppColors.primaryDarkBlue
//                                                 : Colors.grey,
//                                             fontSize: 14,
//                                             fontWeight: FontWeight.w600,
//                                             decoration: _isResendEnabled
//                                                 ? TextDecoration.underline
//                                                 : TextDecoration.none,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           // Loading Overlay
//           if (_isLoading)
//             Container(
//               color: Colors.black.withOpacity(0.3),
//               child: const Center(
//                 child: CircularProgressIndicator(
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionButton({
//     required VoidCallback onPressed,
//     required String text,
//     required IconData icon,
//   }) {
//     return SizedBox(
//       width: double.infinity,
//       height: 58,
//       child: ElevatedButton(
//         onPressed: _isLoading ? null : onPressed,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.primaryDarkBlue,
//           foregroundColor: Colors.white,
//           elevation: 8,
//           shadowColor: AppColors.primaryDarkBlue.withOpacity(0.4),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               text,
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 letterSpacing: 0.5,
//               ),
//             ),
//             const SizedBox(width: 8),
//             Icon(icon, size: 22),
//           ],
//         ),
//       ),
//     );
//   }
// }