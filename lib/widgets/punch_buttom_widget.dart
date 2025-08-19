import 'package:flutter/material.dart';

class PunchButtonWidget extends StatefulWidget {
  final VoidCallback onPunch;

  const PunchButtonWidget({super.key, required this.onPunch});

  // FIX: Renamed the return type to the now public PunchButtonWidgetState.
  @override
  PunchButtonWidgetState createState() => PunchButtonWidgetState();
}

// FIX: Renamed the class to make it public.
class PunchButtonWidgetState extends State<PunchButtonWidget> {
  bool _isPunchedIn = false;

  void _handlePunch() {
    setState(() {
      _isPunchedIn = !_isPunchedIn;
    });
    widget.onPunch();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = _isPunchedIn ? Colors.redAccent : Colors.green;
    final String buttonText = _isPunchedIn ? 'Punch Out' : 'Punch In';
    final IconData buttonIcon = _isPunchedIn ? Icons.exit_to_app : Icons.fingerprint;

    return GestureDetector(
      onTap: _handlePunch,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 150,
        width: 150,
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: .1),
          shape: BoxShape.circle,
          border: Border.all(
            color: primaryColor,
            width: 3,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                buttonIcon,
                size: 60,
                color: primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                buttonText,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}