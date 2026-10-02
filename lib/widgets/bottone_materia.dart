import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottoneMateria extends StatelessWidget {
  final String nome;
  final Color colore;
  final IconData icona;
  final VoidCallback onTap;

  const BottoneMateria({
    super.key,
    required this.nome,
    required this.colore,
    required this.icona,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colore,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.coloreOmbra,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icona, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(nome, style: AppTheme.titoloBottone),
          ],
        ),
      ),
    );
  }
}