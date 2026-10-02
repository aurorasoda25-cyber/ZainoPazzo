import 'package:flutter/material.dart';
import '../models/scheda.dart';
import '../services/supabase_service.dart';
import 'scheda_screen.dart';

class GenitoreScreen extends StatefulWidget {
  const GenitoreScreen({super.key});

  @override
  State<GenitoreScreen> createState() => _GenitoreScreenState();
}

class _GenitoreScreenState extends State<GenitoreScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getTutteLeSchede();
  }

  void _ricarica() {
    setState(() {
      _future = SupabaseService.getTutteLeSchede();
    });
  }

  String _data(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Area genitori'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _ricarica),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Errore: ${snap.error}'));
          }

          final righe = snap.data ?? [];
          if (righe.isEmpty) {
            return const Center(child: Text('Nessuna scheda'));
          }

          return ListView.separated(
            itemCount: righe.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = righe[i];
              final scheda = Scheda.fromJson(r);
              final materia = (r['mat'] as Map?)?['nome'] ?? '';

              return ListTile(
                leading: Icon(
                  scheda.corretta
                      ? Icons.verified
                      : scheda.completata
                          ? Icons.hourglass_top
                          : Icons.radio_button_unchecked,
                  color: scheda.corretta
                      ? Colors.green
                      : scheda.completata
                          ? Colors.orange
                          : Colors.grey,
                ),
                title: Text(scheda.titolo),
                subtitle: Text(
                  scheda.corretta && scheda.correttaIl != null
                      ? '$materia · corretta il ${_data(scheda.correttaIl!)}'
                      : scheda.completata
                          ? '$materia · da correggere'
                          : '$materia · da completare',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  print('>>> tap su scheda ${scheda.id}');
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SchedaScreen(scheda: scheda, autore: 'genitore'),
                    ),
                  );
                  if (mounted) _ricarica();
                },
              );
            },
          );
        },
      ),
    );
  }
}