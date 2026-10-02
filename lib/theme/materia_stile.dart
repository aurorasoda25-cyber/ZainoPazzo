// lib/theme/materia_stile.dart
import 'package:flutter/material.dart';

class MateriaStile {
  final Color colore;
  final IconData icona;

  const MateriaStile({required this.colore, required this.icona});

  static const Map<String, MateriaStile> mappa = {
    'Italiano': MateriaStile(colore: Color(0xFFE8734A), icona: Icons.menu_book),
    'Matematica': MateriaStile(colore: Color(0xFF4A90D9), icona: Icons.calculate),
    'Storia': MateriaStile(colore: Color.fromARGB(255, 93, 25, 0), icona: Icons.account_balance),
    'Geografia': MateriaStile(colore: Color.fromARGB(255, 88, 185, 207), icona: Icons.public),
    'Musica': MateriaStile(colore: Color.fromARGB(255, 206, 0, 83), icona: Icons.music_note),
    'Arte': MateriaStile(colore: Color.fromARGB(255, 132, 0, 161), icona: Icons.palette),
    'Scienze': MateriaStile(colore: Color.fromARGB(255, 13, 255, 0), icona: Icons.science),
    'Inglese': MateriaStile(colore: Color.fromARGB(255, 6, 0, 96), icona: Icons.language),
  };

  static MateriaStile perNome(String nome) {
    return mappa[nome] ??
        const MateriaStile(colore: Colors.grey, icona: Icons.school);
  }
}