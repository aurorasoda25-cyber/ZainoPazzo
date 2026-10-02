import 'dart:async';
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';

class Tratto {
  final int colore;
  final double spessore;
  final List<Offset> punti; // coordinate normalizzate 0..1
  final String autore; // 'bimbo' oppure 'genitore'

  Tratto({
    required this.colore,
    required this.spessore,
    required this.punti,
    this.autore = 'bimbo',
  });

  Map<String, dynamic> toJson() => {
        'colore': colore,
        'spessore': spessore,
        'autore': autore,
        'punti': punti.map((p) => [p.dx, p.dy]).toList(),
      };

  factory Tratto.fromJson(Map<String, dynamic> json) => Tratto(
        colore: json['colore'] as int,
        spessore: (json['spessore'] as num).toDouble(),
        autore: json['autore'] as String? ?? 'bimbo',
        punti: (json['punti'] as List)
            .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList(),
      );
}

class CanvasDisegno extends StatefulWidget {
  final List<Tratto> trattiIniziali;
  final Color colore;
  final double spessore;
  final bool attivo;
  final String autore;
  final void Function(List<Tratto>) onModificato;

  const CanvasDisegno({
    super.key,
    required this.trattiIniziali,
    required this.colore,
    required this.spessore,
    required this.attivo,
    required this.onModificato,
    this.autore = 'bimbo',
  });

  @override
  State<CanvasDisegno> createState() => CanvasDisegnoState();
}

class CanvasDisegnoState extends State<CanvasDisegno> {
  late List<Tratto> _tratti;
  Tratto? _corrente;
  Timer? _timer;
  bool _daSalvare = false;

  @override
  void initState() {
    super.initState();
    _tratti = List.of(widget.trattiIniziali);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_daSalvare) widget.onModificato(_tratti);
    super.dispose();
  }

  // Annulla l'ultimo tratto di chi sta usando lo strumento (bimbo o genitore)
  void annulla() {
    final i = _tratti.lastIndexWhere((t) => t.autore == widget.autore);
    if (i == -1) return;
    setState(() => _tratti.removeAt(i));
    _programmaSalvataggio();
  }

  void _programmaSalvataggio() {
    _daSalvare = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 800), () {
      _daSalvare = false;
      widget.onModificato(_tratti);
    });
  }

  Offset _norm(Offset p, Size s) =>
      Offset((p.dx / s.width).clamp(0.0, 1.0), (p.dy / s.height).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return IgnorePointer(
        ignoring: !widget.attivo,
        child: Listener(
          onPointerDown: (e) {
            setState(() {
              _corrente = Tratto(
                colore: widget.colore.value,
                spessore: widget.spessore,
                autore: widget.autore,
                punti: [_norm(e.localPosition, size)],
              );
              _tratti.add(_corrente!);
            });
          },
          onPointerMove: (e) {
            if (_corrente == null) return;
            setState(() => _corrente!.punti.add(_norm(e.localPosition, size)));
          },
          onPointerUp: (_) {
            _corrente = null;
            _programmaSalvataggio();
          },
          child: CustomPaint(
            size: size,
            painter: _TrattiPainter(_tratti),
          ),
        ),
      );
    });
  }
}

class _TrattiPainter extends CustomPainter {
  final List<Tratto> tratti;
  _TrattiPainter(this.tratti);

  @override
  void paint(Canvas canvas, Size size) {
    for (final t in tratti) {
      final paint = Paint()
        ..color = Color(t.colore)
        ..strokeWidth = t.spessore
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final pts = t.punti
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();
      if (pts.length == 1) {
        canvas.drawPoints(PointMode.points, pts, paint);
        continue;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrattiPainter old) => true;
}