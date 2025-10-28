import 'package:flutter/material.dart'; 

enum AlertCode {
  codeBlue,
  codeYellow,
  codeOrange,
  codeGreen,
  codeWhite,
  notification,
}

class PatientAlert {
  final AlertCode code;
  final String title;
  final String message;
  final String time;
  final IconData? icon; 
  final Color? iconColor; 

  PatientAlert({
    required this.code,
    required this.title,
    required this.message,
    required this.time,
    this.icon,
    this.iconColor,
  });
}