import 'package:flutter/material.dart';
import '../models/testo_item.dart';

class LivelloTesti extends StatefulWidget {
  final List<TestoItem> testiIniziali;
  final bool attivo; // true solo in modalità testo
  final Color colore;
  final String autore;
  final ValueChanged<List<TestoItem>> onModificato;

  const LivelloTesti({
    super.key,
    required this.testiIniziali,
    required this.attivo,
    required this.colore,
    required this.autore,
    required this.onModificato,
  });

  @override
  State<LivelloTesti> createState() => LivelloTestiState();
}

class LivelloTestiState extends State<LivelloTesti> {
  late final List<TestoItem> _testi = List.of(widget.testiIniziali);
  // cronologia per l'annulla: ogni voce è lo stato dei testi PRIMA di una modifica
  final List<List<Map<String, dynamic>>> _storia = [];
  String? _selId;
  double _dimBase = 0.035;

  TestoItem? get _sel {
    for (final t in _testi) {
      if (t.id == _selId) return t;
    }
    return null;
  }

  void _snapshot() => _storia.add(_testi.map((t) => t.toJson()).toList());

  /// Annulla l'ultima modifica ai testi. Restituisce false se non c'è nulla da annullare.
  bool annulla() {
    if (_storia.isEmpty) return false;
    final s = _storia.removeLast();
    setState(() {
      _testi
        ..clear()
        ..addAll(s.map((j) => TestoItem.fromJson(j)));
      _selId = null;
    });
    widget.onModificato(_testi);
    return true;
  }

  @override
  void didUpdateWidget(covariant LivelloTesti old) {
    super.didUpdateWidget(old);
    if (!widget.attivo) _selId = null;
    // cambiando colore con un testo selezionato, il testo prende il colore
    if (old.colore != widget.colore && widget.attivo) {
      final s = _sel;
      if (s != null) {
        _snapshot();
        s.colore = widget.colore.value;
        widget.onModificato(_testi);
      }
    }
  }

  Future<String?> _chiediTesto(String iniziale) {
    final c = TextEditingController(text: iniziale);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _crea(Offset pos, Size size) async {
    final testo = await _chiediTesto('');
    if (testo == null || testo.trim().isEmpty) return;
    final nuovo = TestoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      testo: testo,
      x: pos.dx / size.width,
      y: pos.dy / size.height,
      colore: widget.colore.value,
      autore: widget.autore,
    );
    _snapshot();
    setState(() {
      _testi.add(nuovo);
      _selId = nuovo.id;
    });
    widget.onModificato(_testi);
  }

  Future<void> _modifica(TestoItem t) async {
    final nuovo = await _chiediTesto(t.testo);
    if (nuovo == null) return;
    _snapshot();
    setState(() {
      if (nuovo.trim().isEmpty) {
        _testi.remove(t);
        _selId = null;
      } else {
        t.testo = nuovo;
      }
    });
    widget.onModificato(_testi);
  }

  void _scala(TestoItem t, double f) {
    _snapshot();
    setState(() => t.dimensione = (t.dimensione * f).clamp(0.015, 0.2));
    widget.onModificato(_testi);
  }

  void _elimina(TestoItem t) {
    _snapshot();
    setState(() {
      _testi.remove(t);
      _selId = null;
    });
    widget.onModificato(_testi);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      // se non è in modalità testo, i tocchi passano al livello sotto
      return IgnorePointer(
        ignoring: !widget.attivo,
        child: Stack(
          children: [
            // tocco su zona vuota: deseleziona, oppure crea un nuovo testo.
            // Gestisce solo il tap, quindi lo scorrimento della pagina resta libero.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) {
                  if (_selId != null) {
                    setState(() => _selId = null);
                  } else {
                    _crea(d.localPosition, size);
                  }
                },
              ),
            ),
            for (final t in _testi) _voce(t, size),
          ],
        ),
      );
    });
  }

  Widget _voce(TestoItem t, Size size) {
    final sel = t.id == _selId;
    final maxW = (size.width * (1 - t.x)).clamp(180.0, size.width);
    return Positioned(
      left: t.x * size.width,
      top: t.y * size.height,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selId = t.id),
              onDoubleTap: () => _modifica(t),
              // un dito = sposta, due dita = ingrandisci/rimpicciolisci
              onScaleStart: (_) {
                _snapshot(); // stato prima dello spostamento/ridimensionamento
                _selId = t.id;
                _dimBase = t.dimensione;
              },
              onScaleUpdate: (d) {
                setState(() {
                  t.x += d.focalPointDelta.dx / size.width;
                  t.y += d.focalPointDelta.dy / size.height;
                  if (d.pointerCount > 1) {
                    t.dimensione = (_dimBase * d.scale).clamp(0.015, 0.2);
                  }
                });
              },
              onScaleEnd: (_) => widget.onModificato(_testi),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: sel
                      ? Border.all(color: Colors.blueAccent, width: 1.5)
                      : null,
                ),
                child: Text(
                  t.testo,
                  style: TextStyle(
                    fontSize: t.dimensione * size.width,
                    color: Color(t.colore),
                    height: 1.1,
                  ),
                ),
              ),
            ),
            if (sel) _barra(t),
          ],
        ),
      ),
    );
  }

  Widget _barra(TestoItem t) {
    Widget ib(IconData i, VoidCallback f) => IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          icon: Icon(i),
          onPressed: f,
        );
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ib(Icons.edit, () => _modifica(t)),
          ib(Icons.text_decrease, () => _scala(t, 0.8)),
          ib(Icons.text_increase, () => _scala(t, 1.25)),
          ib(Icons.delete_outline, () => _elimina(t)),
        ],
      ),
    );
  }
}
