class Scheda {
  final int id;
  final int materiaId;
  final String titolo;
  final String pdfPath;
  final int ordine;
  final bool completata;
  final DateTime? completataIl;
  final bool corretta;
  final DateTime? correttaIl;
  final bool correzioneVista;

  Scheda({
    required this.id,
    required this.materiaId,
    required this.titolo,
    required this.pdfPath,
    this.ordine = 0,
    this.completata = false,
    this.completataIl,
    this.corretta = false,
    this.correttaIl,
    this.correzioneVista = true,
  });

  factory Scheda.fromJson(Map<String, dynamic> json) {
    return Scheda(
      id: (json['id'] as num).toInt(),
      materiaId: (json['materia'] as num).toInt(),
      titolo: json['titolo']?.toString() ?? 'Senza titolo',
      pdfPath: json['pdf_path']?.toString() ?? '',
      ordine: (json['ordine'] as num?)?.toInt() ?? 0,
      completata: json['completata'] as bool? ?? false,
      completataIl: json['completata_il'] != null
          ? DateTime.parse(json['completata_il'] as String).toLocal()
          : null,
      corretta: json['corretta'] as bool? ?? false,
      correttaIl: json['corretta_il'] != null
          ? DateTime.parse(json['corretta_il'] as String).toLocal()
          : null,
      correzioneVista: json['correzione_vista'] as bool? ?? true,
    );
  }
}