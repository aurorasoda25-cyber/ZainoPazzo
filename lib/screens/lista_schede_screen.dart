import 'package:flutter/material.dart';
import '../models/materia.dart';
import '../models/scheda.dart';
import '../services/supabase_service.dart';
import '../theme/materia_stile.dart';
import 'scheda_screen.dart';

class ListaSchedeScreen extends StatefulWidget {
  final Materia materia;
  const ListaSchedeScreen({super.key, required this.materia});

  @override
  State<ListaSchedeScreen> createState() => _ListaSchedeScreenState();
}

class _ListaSchedeScreenState extends State<ListaSchedeScreen> {
  late Future<List<Scheda>> _futureSchede;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  void _carica() {
    _futureSchede = SupabaseService.getSchedePerMateria(widget.materia.id);
  }

  Widget _trailing(Scheda scheda, bool daFare) {
    if (daFare) {
      return const Icon(Icons.edit, size: 32);
    }
    if (scheda.corretta) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!scheda.correzioneVista)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'NUOVO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const Icon(Icons.verified, color: Colors.green, size: 32),
        ],
      );
    }
    // completata ma non ancora corretta
    return const Icon(Icons.hourglass_top, color: Colors.orange, size: 32);
  }

  @override
  Widget build(BuildContext context) {
    final stile = MateriaStile.perNome(widget.materia.nome);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.materia.nome),
        backgroundColor: stile.colore,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Scheda>>(
        future: _futureSchede,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          final schede = snapshot.data ?? [];
          if (schede.isEmpty) {
            return const Center(child: Text('Nessuna scheda per questa materia'));
          }

          // La prima scheda non completata è quella "da fare".
          // Si vedono solo le precedenti (già fatte) e quella.
          final indiceCorrente = schede.indexWhere((s) => !s.completata);
          final visibili = indiceCorrente == -1
              ? schede
              : schede.sublist(0, indiceCorrente + 1);
          final tutteFatte = indiceCorrente == -1;

          return Column(
            children: [
              if (tutteFatte)
                Container(
                  width: double.infinity,
                  color: Colors.green.withOpacity(0.15),
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    '🎉 Hai finito tutte le schede di questa materia!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibili.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final scheda = visibili[i];
                    final daFare = i == indiceCorrente;

                    return ListTile(
                      tileColor: stile.colore.withOpacity(daFare ? 0.35 : 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: daFare
                            ? BorderSide(color: stile.colore, width: 3)
                            : BorderSide.none,
                      ),
                      leading: Icon(
                        Icons.description,
                        color: stile.colore,
                        size: 32,
                      ),
                      title: Text(
                        scheda.titolo,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: daFare ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(daFare ? 'Da fare' : 'Solo da guardare'),
                      trailing: _trailing(scheda, daFare),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SchedaScreen(
                              scheda: scheda,
                              soloLettura: !daFare,
                            ),
                          ),
                        );
                        // al ritorno ricarico: si sblocca la scheda successiva
                        if (mounted) setState(_carica);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}