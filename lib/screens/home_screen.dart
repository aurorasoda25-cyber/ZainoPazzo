import 'dart:async';
import 'package:flutter/material.dart';
import '../models/materia.dart';
import '../services/supabase_service.dart';
import '../theme/materia_stile.dart';
import '../widgets/bottone_materia.dart';
import 'genitore_screen.dart';
import 'lista_schede_screen.dart';
import 'orario_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Cambia questo PIN
  static const String _pinGenitore = '1876';

  late Future<List<Materia>> _futureMaterie;
  StreamSubscription? _sub;
  int _ultimoConteggio = 0;

  @override
  void initState() {
    super.initState();
    _futureMaterie = SupabaseService.getMaterie();
    _ascoltaCorrezioni();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // Notifica in tempo reale: compare quando ci sono correzioni non ancora viste
  void _ascoltaCorrezioni() {
    _sub = SupabaseService.client
        .from('scheda')
        .stream(primaryKey: ['id'])
        .listen(
      (righe) {
        final nuove = righe
            .where((r) => r['corretta'] == true && r['correzione_vista'] == false)
            .length;

        if (nuove > _ultimoConteggio && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 6),
              content: Text(
                nuove == 1
                    ? '🎉 Una tua scheda è stata corretta!'
                    : '🎉 $nuove schede sono state corrette!',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          );
        }
        _ultimoConteggio = nuove;
      },
      onError: (e) => print('>>> ERRORE stream schede: $e'),
    );
  }

  Future<void> _apriAreaGenitore() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Area genitori'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text == _pinGenitore),
            child: const Text('Entra'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GenitoreScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/sfondo_home.png',
              fit: BoxFit.cover,
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: FutureBuilder<List<Materia>>(
                future: _futureMaterie,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Non riesco a connettermi. Controlla internet.'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => setState(() {
                            _futureMaterie = SupabaseService.getMaterie();
                          }),
                          child: const Text('Riprova'),
                        ),
                      ],
                    );
                  }

                  final materie = snapshot.data ?? [];

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      const spaziatura = 24.0;
                      const numeroPerRiga = 3;
                      final larghezzaBottone =
                          (constraints.maxWidth - spaziatura * (numeroPerRiga - 1)) /
                              numeroPerRiga;

                      return Wrap(
                        alignment: WrapAlignment.center,
                        spacing: spaziatura,
                        runSpacing: spaziatura,
                        children: materie.map((materia) {
                          final stile = MateriaStile.perNome(materia.nome);
                          return SizedBox(
                            width: larghezzaBottone,
                            height: 120,
                            child: BottoneMateria(
                              nome: materia.nome,
                              colore: stile.colore,
                              icona: stile.icona,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListaSchedeScreen(materia: materia),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Icona discreta per l'area genitori
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.lock, color: Colors.white70),
                tooltip: 'Area genitori',
                onPressed: _apriAreaGenitore,
              ),
            ),
          ),

          // Bottone immagine, in basso al centro
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                heroTag: 'bottoneImmagine',
                backgroundColor: const Color.fromARGB(220, 44, 118, 214),
                icon: const Icon(Icons.access_time,  color: Colors.white),
                label: const Text('Orario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImmagineScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}