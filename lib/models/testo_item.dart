class TestoItem {
  String id;
  String testo;
  double x, y;        // 0..1 rispetto alla pagina
  double dimensione;  // frazione della larghezza pagina
  int colore;
  String autore;

  TestoItem({
    required this.id,
    required this.testo,
    required this.x,
    required this.y,
    this.dimensione = 0.035,
    required this.colore,
    required this.autore,
  });

  factory TestoItem.fromJson(Map<String, dynamic> j) => TestoItem(
        id: j['id'],
        testo: j['testo'],
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        dimensione: (j['dim'] as num).toDouble(),
        colore: j['colore'],
        autore: j['autore'] ?? 'bimbo',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'testo': testo,
        'x': x,
        'y': y,
        'dim': dimensione,
        'colore': colore,
        'autore': autore,
      };
}
