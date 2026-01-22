import 'package:flutter/material.dart';

class AIFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AIFloatingButton({Key? key, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: onPressed,
        child: const Icon(Icons.smart_toy),
      ),
    );
  }
}
