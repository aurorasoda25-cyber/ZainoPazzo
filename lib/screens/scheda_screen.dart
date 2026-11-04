import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/scheda.dart';
import '../models/testo_item.dart';
import '../services/supabase_service.dart';
import '../widgets/canvas_disegno.dart';
import '../widgets/livello_testi.dart';

/// Strumenti disponibili: matita (disegna), mano (scorri), testo.
enum Strumento { matita, mano, testo }

/// Una modifica fatta dall'utente, per l'annulla in ordine cronologico.
class _Azione {
  final int pagina;
  final bool testo; // true = modifica ai testi, false = tratto a mano libera
  const _Azione(this.pagina, this.testo);
}

class SchedaScreen extends StatefulWidget {
  final Scheda scheda;
  final bool soloLettura;
  final String autore; // 'bimbo' oppure 'genitore'

  const SchedaScreen({
    super.key,
    required this.scheda,
    this.soloLettura = false,
    this.autore = 'bimbo',
  });

  @override
  State<SchedaScreen> createState() => _SchedaScreenState();
}

class _SchedaScreenState extends State<SchedaScreen> {
  PdfDocument? _doc;
  final Map<int, List<Tratto>> _tratti = {}; // pagina (1-based) -> tratti
  final Map<int, List<TestoItem>> _testi = {}; // pagina (1-based) -> testi
  final Map<int, GlobalKey<CanvasDisegnoState>> _keys = {};
  final Map<int, GlobalKey<LivelloTestiState>> _keysTesti = {};
  final List<_Azione> _azioni = []; // cronologia per l'annulla
  bool _inAnnulla = false;
  bool _caricamento = true;
  String? _errore;
  String _stato = 'Avvio...';

  Strumento _strumento = Strumento.matita;
  bool get _disegna => _strumento == Strumento.matita;

  Color _colore = Colors.blue;
  double _spessore = 4;
  int _paginaAttiva = 1;

  // Zoom a pulsanti: 1.0 = pagina larga come lo schermo
  double _zoom = 1.0;
  static const double _zoomMin = 1.0;
  static const double _zoomMax = 3.0;
  static const double _zoomStep = 0.5;

  // 4 neutri + 12 tinte in 3 sfumature (scura, media, chiara)
  final List<Color> _palette = [
    Colors.black,
    const Color(0xFF555555),
    const Color(0xFF999999),
    Colors.white,
    for (final h in [0, 20, 40, 55, 90, 140, 170, 195, 215, 250, 280, 320])
      for (final l in [0.30, 0.50, 0.75])
        HSLColor.fromAHSL(1, h.toDouble(), 0.85, l).toColor(),
  ];

  void _log(String msg) {
    print('>>> $msg');
    if (mounted) setState(() => _stato = msg);
  }

  void _cambiaZoom(double delta) {
    setState(() => _zoom = (_zoom + delta).clamp(_zoomMin, _zoomMax));
  }

  @override
  void initState() {
    super.initState();
    print('>>> SchedaScreen initState, pdfPath: "${widget.scheda.pdfPath}"');
    _strumento = widget.soloLettura ? Strumento.mano : Strumento.matita;
    if (widget.autore == 'genitore') _colore = Colors.red; // correzioni in rosso

    // il bambino apre una scheda corretta: la notifica "NUOVO" sparisce
    if (widget.autore == 'bimbo' &&
        widget.scheda.corretta &&
        !widget.scheda.correzioneVista) {
      SupabaseService.segnaCorrezioneVista(widget.scheda.id);
    }

    _carica();
  }

  Future<void> _carica() async {
    try {
      _log('1) scarico PDF: ${widget.scheda.pdfPath}');
      final bytes = await SupabaseService.scaricaPdf(widget.scheda.pdfPath);

      _log('2) scaricati ${bytes.length} byte, apro il PDF...');
      final doc = await PdfDocument.openData(
        bytes,
        sourceName: widget.scheda.pdfPath,
      );

      _log('3) aperto: ${doc.pages.length} pagine, leggo tratti e testi...');
      final risultati = await Future.wait([
        for (var p = 1; p <= doc.pages.length; p++)
          SupabaseService.caricaTratti(widget.scheda.id, p),
      ]);
      final testiRis = await Future.wait([
        for (var p = 1; p <= doc.pages.length; p++)
          SupabaseService.caricaTesti(widget.scheda.id, p),
      ]);

      _log('4) dati letti, costruisco la schermata');
      for (var i = 0; i < risultati.length; i++) {
        _tratti[i + 1] = risultati[i]
            .map((j) => Tratto.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        _testi[i + 1] = testiRis[i]
            .map((j) => TestoItem.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        _keys[i + 1] = GlobalKey<CanvasDisegnoState>();
        _keysTesti[i + 1] = GlobalKey<LivelloTestiState>();
      }

      if (!mounted) return;
      setState(() {
        _doc = doc;
        _caricamento = false;
      });
    } catch (e, st) {
      print('>>> ERRORE: $e\n$st');
      if (!mounted) return;
      setState(() {
        _errore = e.toString();
        _caricamento = false;
      });
    }
  }

  @override
  void dispose() {
    _doc?.dispose();
    super.dispose();
  }

  Future<void> _salva(int pagina, List<Tratto> tratti) async {
    _tratti[pagina] = tratti;
    try {
      await SupabaseService.salvaTratti(
        widget.scheda.id,
        pagina,
        tratti.map((t) => t.toJson()).toList(),
      );
      print('>>> salvata pagina $pagina (${tratti.length} tratti)');
    } catch (e) {
      print('>>> ERRORE salvataggio: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvataggio non riuscito: $e')),
      );
    }
  }

  Future<void> _salvaTesti(int pagina, List<TestoItem> testi) async {
    _testi[pagina] = List.of(testi);
    try {
      await SupabaseService.salvaTesti(
        widget.scheda.id,
        pagina,
        testi.map((t) => t.toJson()).toList(),
      );
      print('>>> salvati testi pagina $pagina (${testi.length} testi)');
    } catch (e) {
      print('>>> ERRORE salvataggio testi: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvataggio testo non riuscito: $e')),
      );
    }
  }

  // Annulla l'ultima modifica (tratto o testo), in ordine cronologico
  void _annulla() {
    if (_azioni.isEmpty) {
      // nessuna azione di questa sessione: lascia fare al canvas come prima
      _keys[_paginaAttiva]?.currentState?.annulla();
      return;
    }
    final a = _azioni.removeLast();
    _paginaAttiva = a.pagina;
    _inAnnulla = true; // l'annullamento stesso non deve finire nella cronologia
    try {
      if (a.testo) {
        _keysTesti[a.pagina]?.currentState?.annulla();
      } else {
        _keys[a.pagina]?.currentState?.annulla();
      }
    } finally {
      _inAnnulla = false;
    }
  }

  // Bambino: consegna la scheda
  Future<void> _finito() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hai finito la scheda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non ancora'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sì, ho finito!'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SupabaseService.segnaCompletata(widget.scheda.id, true);
    if (mounted) Navigator.pop(context);
  }

  // Genitore: correzione terminata, parte la notifica al bambino
  Future<void> _correzioneFinita() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Correzione finita?'),
        content: const Text(
          'Al bambino arriverà la notifica che la scheda è corretta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non ancora'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sì, invia'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SupabaseService.segnaCorretta(widget.scheda.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sceltaColorePersonalizzato() async {
    var hsv = HSVColor.fromColor(_colore);
    final scelto = await showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Scegli un colore'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: hsv.toColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Tinta'),
              Slider(
                min: 0,
                max: 360,
                value: hsv.hue,
                onChanged: (v) => setD(() => hsv = hsv.withHue(v)),
              ),
              const Text('Intensità'),
              Slider(
                min: 0,
                max: 1,
                value: hsv.saturation,
                onChanged: (v) => setD(() => hsv = hsv.withSaturation(v)),
              ),
              const Text('Chiaro / scuro'),
              Slider(
                min: 0,
                max: 1,
                value: hsv.value,
                onChanged: (v) => setD(() => hsv = hsv.withValue(v)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, hsv.toColor()),
              child: const Text('Usa'),
            ),
          ],
        ),
      ),
    );
    if (scelto != null) setState(() => _colore = scelto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scheda.titolo),
        actions: widget.soloLettura
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Annulla',
                  onPressed: _annulla,
                ),
                // matita <-> mano
                IconButton(
                  icon: Icon(_disegna ? Icons.edit : Icons.pan_tool),
                  tooltip: _disegna ? 'Modalità matita' : 'Modalità scorri',
                  onPressed: () => setState(() => _strumento =
                      _disegna ? Strumento.mano : Strumento.matita),
                ),
                // l'icona del testo compare quando sei in modalità mano
                if (!_disegna)
                  IconButton(
                    icon: const Icon(Icons.text_fields),
                    tooltip: 'Testo',
                    isSelected: _strumento == Strumento.testo,
                    onPressed: () => setState(() => _strumento =
                        _strumento == Strumento.testo
                            ? Strumento.mano
                            : Strumento.testo),
                  ),
                if (widget.autore == 'bimbo')
                  TextButton.icon(
                    onPressed: _finito,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Ho finito'),
                  )
                else
                  TextButton.icon(
                    onPressed: _correzioneFinita,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Correzione finita'),
                  ),
              ],
      ),
      body: _corpo(),
      bottomNavigationBar: _caricamento || _errore != null || widget.soloLettura
          ? null
          : _barraStrumenti(),
    );
  }

  Widget _corpo() {
    if (_caricamento) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_stato, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    if (_errore != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Errore: $_errore'),
        ),
      );
    }

    final doc = _doc!;
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, vincoli) {
            return SingleChildScrollView(
              // scorrimento orizzontale (serve quando la pagina è ingrandita):
              // in modalità matita il dito disegna, non scorre
              scrollDirection: Axis.horizontal,
              physics: _disegna ? const NeverScrollableScrollPhysics() : null,
              child: SizedBox(
                // con lo zoom la pagina diventa più larga dello schermo
                width: vincoli.maxWidth * _zoom,
                height: vincoli.maxHeight,
                child: ListView.builder(
                  physics: _disegna ? const NeverScrollableScrollPhysics() : null,
                  padding: const EdgeInsets.all(12),
                  itemCount: doc.pages.length,
                  itemBuilder: (context, i) {
                    final pagina = i + 1;
                    final p = doc.pages[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AspectRatio(
                        aspectRatio: p.width / p.height,
                        child: Material(
                          elevation: 4,
                          color: Colors.white,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _PaginaPdf(page: p),
                              CanvasDisegno(
                                key: _keys[pagina],
                                autore: widget.autore,
                                trattiIniziali: _tratti[pagina] ?? [],
                                colore: _colore,
                                spessore: _spessore,
                                attivo: _disegna && !widget.soloLettura,
                                onModificato: (t) {
                                  _paginaAttiva = pagina;
                                  if (!_inAnnulla) {
                                    _azioni.add(_Azione(pagina, false));
                                  }
                                  _salva(pagina, t);
                                },
                              ),
                              // livello dei testi, sopra il disegno
                              LivelloTesti(
                                key: _keysTesti[pagina],
                                autore: widget.autore,
                                testiIniziali: _testi[pagina] ?? [],
                                colore: _colore,
                                attivo: _strumento == Strumento.testo &&
                                    !widget.soloLettura,
                                onModificato: (t) {
                                  _paginaAttiva = pagina;
                                  if (!_inAnnulla) {
                                    _azioni.add(_Azione(pagina, true));
                                  }
                                  _salvaTesti(pagina, t);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),

        // Pulsanti zoom + e -
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'zoomPiu',
                tooltip: 'Ingrandisci',
                onPressed:
                    _zoom < _zoomMax ? () => _cambiaZoom(_zoomStep) : null,
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'zoomMeno',
                tooltip: 'Rimpicciolisci',
                onPressed:
                    _zoom > _zoomMin ? () => _cambiaZoom(-_zoomStep) : null,
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _barraStrumenti() {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // colore personalizzato
                  GestureDetector(
                    onTap: _sceltaColorePersonalizzato,
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(colors: [
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ]),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                  for (final c in _palette)
                    GestureDetector(
                      onTap: () => setState(() => _colore = c),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colore == c ? Colors.black : Colors.black26,
                            width: _colore == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: _spessore + 8,
                  height: _spessore + 8,
                  decoration: BoxDecoration(
                    color: _colore,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Slider(
                    min: 2,
                    max: 24,
                    value: _spessore,
                    onChanged: (v) => setState(() => _spessore = v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginaPdf extends StatefulWidget {
  final PdfPage page;
  const _PaginaPdf({required this.page});

  @override
  State<_PaginaPdf> createState() => _PaginaPdfState();
}

class _PaginaPdfState extends State<_PaginaPdf> {
  // Limite di larghezza in pixel del rendering: evita di consumare troppa
  // memoria quando la pagina è molto ingrandita
  static const int _maxPixelLarghezza = 2800;

  ui.Image? _img;
  String? _err;
  double _larghezzaRender = 0; // larghezza (in px logici) dell'ultimo render
  bool _inCorso = false;

  Future<void> _render(double larghezza, double dpr) async {
    try {
      final w = math.min((larghezza * dpr).round(), _maxPixelLarghezza);
      final h = (w * widget.page.height / widget.page.width).round();
      final pdfImg = await widget.page.render(
        width: w,
        height: h,
        fullWidth: w.toDouble(),
        fullHeight: h.toDouble(),
      );
      if (pdfImg == null) throw Exception('render ha restituito null');
      final img = await pdfImg.createImage();
      pdfImg.dispose();
      if (!mounted) {
        img.dispose();
        return;
      }
      final vecchia = _img;
      setState(() => _img = img);
      // l'immagine precedente si libera dopo il ridisegno
      WidgetsBinding.instance.addPostFrameCallback((_) => vecchia?.dispose());
    } catch (e) {
      print('>>> ERRORE render pagina: $e');
      if (mounted) setState(() => _err = e.toString());
    } finally {
      _inCorso = false;
    }
  }

  @override
  void dispose() {
    _img?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // primo render, oppure la pagina è cambiata di larghezza (zoom)
      if (!_inCorso && (c.maxWidth - _larghezzaRender).abs() > 1) {
        _inCorso = true;
        _larghezzaRender = c.maxWidth;
        final larghezza = c.maxWidth;
        final dpr = MediaQuery.of(context).devicePixelRatio;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _render(larghezza, dpr);
          } else {
            _inCorso = false;
          }
        });
      }
      if (_err != null) return Center(child: Text('Errore PDF: $_err'));
      if (_img == null) return const Center(child: CircularProgressIndicator());
      return RawImage(image: _img, fit: BoxFit.fill);
    });
  }
}
