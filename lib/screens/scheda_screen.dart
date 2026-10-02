import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/scheda.dart';
import '../services/supabase_service.dart';
import '../widgets/canvas_disegno.dart';

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
  final Map<int, GlobalKey<CanvasDisegnoState>> _keys = {};
  bool _caricamento = true;
  String? _errore;
  String _stato = 'Avvio...';

  bool _disegna = true;
  Color _colore = Colors.blue;
  double _spessore = 4;
  int _paginaAttiva = 1;

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

  @override
  void initState() {
    super.initState();
    print('>>> SchedaScreen initState, pdfPath: "${widget.scheda.pdfPath}"');
    _disegna = !widget.soloLettura;
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

      _log('3) aperto: ${doc.pages.length} pagine, leggo i tratti...');
      final risultati = await Future.wait([
        for (var p = 1; p <= doc.pages.length; p++)
          SupabaseService.caricaTratti(widget.scheda.id, p),
      ]);

      _log('4) tratti letti, costruisco la schermata');
      for (var i = 0; i < risultati.length; i++) {
        _tratti[i + 1] = risultati[i]
            .map((j) => Tratto.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        _keys[i + 1] = GlobalKey<CanvasDisegnoState>();
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
                  onPressed: () => _keys[_paginaAttiva]?.currentState?.annulla(),
                ),
                IconButton(
                  icon: Icon(_disegna ? Icons.edit : Icons.pan_tool),
                  tooltip: _disegna ? 'Modalità matita' : 'Modalità scorri',
                  onPressed: () => setState(() => _disegna = !_disegna),
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
  return ListView.builder(
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
            child: InteractiveViewer(
              panEnabled: false,       // un dito resta libero per disegnare/scrollare
              scaleEnabled: true,      // due dita = pinch zoom
              minScale: 1.0,
              maxScale: 4.0,
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
                      _salva(pagina, t);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
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
  ui.Image? _img;
  String? _err;
  bool _avviato = false;

  Future<void> _render(double larghezza, double dpr) async {
    try {
      final w = (larghezza * dpr).round();
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
      setState(() => _img = img);
    } catch (e) {
      print('>>> ERRORE render pagina: $e');
      if (mounted) setState(() => _err = e.toString());
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
      if (!_avviato) {
        _avviato = true;
        _render(c.maxWidth, MediaQuery.of(context).devicePixelRatio);
      }
      if (_err != null) return Center(child: Text('Errore PDF: $_err'));
      if (_img == null) return const Center(child: CircularProgressIndicator());
      return RawImage(image: _img, fit: BoxFit.fill);
    });
  }
}