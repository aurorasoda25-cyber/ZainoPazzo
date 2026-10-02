import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/materia.dart';
import '../models/scheda.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // Nome del bucket Storage in cui stanno i PDF: controllalo in Supabase -> Storage
  static const String bucketSchede = 'schede';

  static Future<List<Materia>> getMaterie() async {
    final response = await client.from('materia').select().order('id');

    return (response as List).map((json) => Materia.fromJson(json)).toList();
  }

  static Future<List<Scheda>> getSchedePerMateria(int materiaId) async {
    final response = await client
        .from('scheda')
        .select()
        .eq('materia', materiaId)
        .order('ordine', ascending: true)
        .order('titolo');

    return (response as List).map((json) => Scheda.fromJson(json)).toList();
  }

  // Tutte le schede con il nome della materia (serve la foreign key scheda.materia_id -> materia.id)
static Future<List<Map<String, dynamic>>> getTutteLeSchede() async {
  final r = await client
      .from('scheda')
      .select('*, mat:materia(nome)') // alias "mat" per il join
      .order('completata_il', ascending: false, nullsFirst: false);
  return List<Map<String, dynamic>>.from(r);
}
  static Future<void> segnaCompletata(int schedaId, bool completata) async {
  await client.from('scheda').update({
    'completata': completata,
    'completata_il': completata ? DateTime.now().toIso8601String() : null,
    // se il bambino consegna di nuovo, si riparte da "da correggere"
    'corretta': false,
    'corretta_il': null,
    'correzione_vista': true,
  }).eq('id', schedaId);
}

static Future<void> segnaCorretta(int schedaId) async {
  await client.from('scheda').update({
    'corretta': true,
    'corretta_il': DateTime.now().toIso8601String(),
    'correzione_vista': false, // => notifica per il bambino
  }).eq('id', schedaId);
}

static Future<void> segnaCorrezioneVista(int schedaId) async {
  await client.from('scheda').update({'correzione_vista': true}).eq('id', schedaId);
}
  static Future<Uint8List> scaricaPdf(String pdfPath) async {
    return await client.storage.from(bucketSchede).download(pdfPath);
  }

  static Future<List<dynamic>> caricaTratti(int schedaId, int pagina) async {
    final r = await client
        .from('annotazioni')
        .select('tratti')
        .eq('scheda_id', schedaId)
        .eq('pagina', pagina)
        .maybeSingle();
    return (r?['tratti'] as List?) ?? [];
  }

  static Future<void> salvaTratti(
    int schedaId,
    int pagina,
    List<Map<String, dynamic>> tratti,
  ) async {
    await client.from('annotazioni').upsert({
      'scheda_id': schedaId,
      'pagina': pagina,
      'tratti': tratti,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'scheda_id,pagina');
  }
}