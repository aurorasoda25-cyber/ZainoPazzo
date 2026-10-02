import 'package:flutter/material.dart';

class ImmagineScreen extends StatelessWidget {
  const ImmagineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(
          child: Image.asset(
            'assets/images/orario.png', // cambia col nome del tuo file
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}