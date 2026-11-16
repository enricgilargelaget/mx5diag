import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import 'car_model.dart';

class Camara {
  final double yaw, pitch, persp;
  const Camara(this.yaw, this.pitch, this.persp);
}

class Vista {
  final String id, etiqueta, nombre;
  final Camara cam;
  final String? cota;
  const Vista(this.id, this.etiqueta, this.nombre, this.cam, [this.cota]);
}

const vistas = [
  Vista('3d', '3D', 'VISTA 3/4 · ARRASTRA PARA GIRAR', Camara(-35, 22, 1)),
  Vista('lateral', 'Lateral', 'ALZADO LATERAL IZQ.', Camara(0, 0, 0), 'LONGITUD ≈ 4.000 mm'),
  Vista('planta', 'Planta', 'PLANTA', Camara(0, 90, 0), 'LONGITUD ≈ 4.000 mm'),
  Vista('frente', 'Frente', 'ALZADO FRONTAL', Camara(-90, 0, 0), 'ANCHURA ≈ 1.720 mm'),
  Vista('trasera', 'Trasera', 'ALZADO POSTERIOR', Camara(90, 0, 0), 'ANCHURA ≈ 1.720 mm'),
  Vista('bajos', 'Bajos', 'VISTA INFERIOR (BAJOS)', Camara(0, -90, 0), 'LONGITUD ≈ 4.000 mm'),
];

class Colores {
  static const fondo = Color(0xFF0F3A80);
  static const linea = Color(0xFFDCEBFF);
  static const meca = Color(0xFFA3ADBB);
  static const cable = Color(0xFFC3CBD6);
  static Color de(Estado e) => const {
        Estado.rojo: Color(0xFFFF6B6B),
        Estado.amarillo: Color(0xFFFFD23F),
        Estado.verde: Color(0xFF3BE38A),
      }[e]!;
  static Color tinta(Estado e) => const {
        Estado.rojo: Color(0xFF1B0606),
        Estado.amarillo: Color(0xFF1E1600),
        Estado.verde: Color(0xFF04170C),
      }[e]!;
}

/// Proyección: devuelve x, y de pantalla (sin escalar) y profundidad.
(double, double, double) proyectar(V3 p, Camara c) {
  final t = c.yaw * math.pi / 180, f = c.pitch * math.pi / 180;
  final x1 = p.x * math.cos(t) + p.z * math.sin(t);
  final z1 = -p.x * math.sin(t) + p.z * math.cos(t);
  final yu = p.y * math.cos(f) - z1 * math.sin(f);
  final d = z1 * math.cos(f) + p.y * math.sin(f);
  final m = 1 + c.persp * d * 0.09;
  return (-x1 * m, -yu * m, d);
}

/// Ajuste del modelo a un rectángulo.
class Encaje {
  final double s, ox, oy, minD, maxD;
  final Rect caja;
  Encaje(this.s, this.ox, this.oy, this.minD, this.maxD, this.caja);

  factory Encaje.de(Camara c, Rect zona) {
    var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9, minD = 1e9, maxD = -1e9;
    for (final (a, b, _) in CarModel.instance.body) {
      for (final p in [a, b]) {
        final q = proyectar(p, c);
        minX = math.min(minX, q.$1);
        maxX = math.max(maxX, q.$1);
        minY = math.min(minY, q.$2);
        maxY = math.max(maxY, q.$2);
        minD = math.min(minD, q.$3);
        maxD = math.max(maxD, q.$3);
      }
    }
    final s = math.min(zona.width / (maxX - minX), zona.height / (maxY - minY));
    final ox = zona.center.dx - s * (minX + maxX) / 2, oy = zona.center.dy - s * (minY + maxY) / 2;
    return Encaje(s, ox, oy, minD, maxD, Rect.fromLTRB(ox + s * minX, oy + s * minY, ox + s * maxX, oy + s * maxY));
  }

  Offset punto(V3 p, Camara c) {
    final q = proyectar(p, c);
    return Offset(ox + s * q.$1, oy + s * q.$2);
  }
}

class PlanoPainter extends CustomPainter {
  final Camara cam;
  final List<Zona> zonas;
  final String? seleccion;
  final bool mecanica, cableado;
  final String? cota;
  final double margenSup, margenInf;
  final bool miniatura;

  PlanoPainter({
    required this.cam,
    required this.zonas,
    this.seleccion,
    this.mecanica = true,
    this.cableado = true,
    this.cota,
    this.margenSup = 58,
    this.margenInf = 58,
    this.miniatura = false,
  });

  Encaje encaje(Size size) =>
      Encaje.de(cam, Rect.fromLTRB(miniatura ? 2 : 24, margenSup, size.width - (miniatura ? 2 : 24), size.height - margenInf - (cota != null ? 28 : 0)));

  @override
  void paint(Canvas canvas, Size size) {
    final e = encaje(size);
    final modelo = CarModel.instance;
    final span = (e.maxD - e.minD) == 0 ? 1 : e.maxD - e.minD;

    if (miniatura) {
      final path = Path();
      for (final (a, b, _) in modelo.body) {
        final pa = e.punto(a, cam), pb = e.punto(b, cam);
        path
          ..moveTo(pa.dx, pa.dy)
          ..lineTo(pb.dx, pb.dy);
      }
      canvas.drawPath(path, _stroke(Colores.linea, 0.6));
      return;
    }

    final lejos = Path(), medio = Path(), cerca = Path();
    for (final (a, b, zona) in modelo.body) {
      if (zona != null) continue; // las piezas con zona se pintan con su color
      final qa = proyectar(a, cam), qb = proyectar(b, cam);
      final d = ((qa.$3 + qb.$3) / 2 - e.minD) / span;
      final destino = d > 0.62 ? cerca : (d > 0.38 ? medio : lejos);
      destino
        ..moveTo(e.ox + e.s * qa.$1, e.oy + e.s * qa.$2)
        ..lineTo(e.ox + e.s * qb.$1, e.oy + e.s * qb.$2);
    }
    Path trazar(List<Seg> segs) {
      final p = Path();
      for (final (a, b, _) in segs) {
        final pa = e.punto(a, cam), pb = e.punto(b, cam);
        p
          ..moveTo(pa.dx, pa.dy)
          ..lineTo(pb.dx, pb.dy);
      }
      return p;
    }

    canvas.drawPath(lejos, _stroke(Colores.linea.withOpacity(0.3), 0.7));
    if (mecanica) canvas.drawPath(trazar(modelo.mech.where((sg) => sg.$3 == null).toList()), _stroke(Colores.meca.withOpacity(0.9), 0.9));
    if (cableado) _discontinua(canvas, modelo.wire, e);
    canvas.drawPath(medio, _stroke(Colores.linea.withOpacity(0.65), 0.9));
    canvas.drawPath(cerca, _stroke(Colores.linea, 1.2));

    // Piezas completas coloreadas (translúcidas) según el estado de su zona
    for (final z in zonas) {
      final sel = z.id == seleccion, ok = z.estado == Estado.verde;
      final color = Colores.de(z.estado);
      final relleno = Path();
      for (final c in modelo.contornos.where((c) => c.zona == z.id)) {
        final pts = c.pts.map((p) => e.punto(p, cam)).toList();
        relleno.addPolygon(pts, true);
      }
      final lineas = trazar([...modelo.body, ...modelo.mech].where((sg) => sg.$3 == z.id).toList());
      canvas.drawPath(relleno, Paint()..color = color.withOpacity(sel ? 0.28 : (ok ? 0.09 : 0.18)));
      canvas.drawPath(lineas, _stroke(color.withOpacity(ok ? 0.07 : 0.16), sel ? 8 : 6)..strokeJoin = StrokeJoin.round);
      canvas.drawPath(lineas, _stroke(sel ? Colors.white : color, sel ? 1.8 : 1.3));
    }

    if (cota != null) _dibujarCota(canvas, e.caja, cota!);
  }

  void _discontinua(Canvas canvas, List<Seg> segs, Encaje e) {
    final paint = _stroke(Colores.cable, 0.8);
    for (final (a, b, _) in segs) {
      final pa = e.punto(a, cam), pb = e.punto(b, cam);
      final len = (pb - pa).distance;
      if (len == 0) continue;
      final dir = (pb - pa) / len;
      for (double t = 0; t < len; t += 5) {
        canvas.drawLine(pa + dir * t, pa + dir * math.min(t + 3, len), paint);
      }
    }
  }

  void _dibujarCota(Canvas canvas, Rect bb, String texto) {
    final y = bb.bottom + 14;
    final p = _stroke(Colores.linea, 0.8);
    canvas.drawLine(Offset(bb.left, y), Offset(bb.right, y), p);
    canvas.drawLine(Offset(bb.left, bb.bottom + 3), Offset(bb.left, y + 5), p);
    canvas.drawLine(Offset(bb.right, bb.bottom + 3), Offset(bb.right, y + 5), p);
    for (final (x, s) in [(bb.left, 1.0), (bb.right, -1.0)]) {
      canvas.drawLine(Offset(x, y), Offset(x + 6 * s, y - 3), p);
      canvas.drawLine(Offset(x, y), Offset(x + 6 * s, y + 3), p);
    }
    final tp = TextPainter(
      text: TextSpan(text: texto, style: const TextStyle(color: Colores.linea, fontSize: 10, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(bb.center.dx - tp.width / 2, y + 4));
  }

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  @override
  bool shouldRepaint(PlanoPainter old) =>
      old.cam != cam || old.mecanica != mecanica || old.cableado != cableado || old.zonas != zonas || old.cota != cota || old.seleccion != seleccion;
}

/// Visor interactivo: arrastrar para girar, puntos y etiquetas pulsables.
class PlanoView extends StatefulWidget {
  final List<Zona> zonas;
  final String? seleccion;
  final ValueChanged<String> onSeleccion;
  final bool mecanica, cableado;
  final Vista vista;
  final Camara? camLibre;
  final ValueChanged<Camara> onCamara;

  const PlanoView({
    super.key,
    required this.zonas,
    required this.onSeleccion,
    required this.vista,
    required this.onCamara,
    this.camLibre,
    this.seleccion,
    this.mecanica = true,
    this.cableado = true,
  });

  @override
  State<PlanoView> createState() => _PlanoViewState();
}

class _PlanoViewState extends State<PlanoView> {
  Camara? _inicio;

  Camara get _cam => widget.camLibre ?? widget.vista.cam;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final cota = widget.camLibre == null ? widget.vista.cota : null;
      final painter = PlanoPainter(
        cam: _cam,
        zonas: widget.zonas,
        seleccion: widget.seleccion,
        mecanica: widget.mecanica,
        cableado: widget.cableado,
        cota: cota,
      );
      final e = painter.encaje(size);
      final puntos = {for (final z in widget.zonas) z.id: e.punto(V3(z.x, z.y, z.z), _cam)};
      final etiquetas = _colocarEtiquetas(size, puntos);

      return GestureDetector(
        onPanStart: (_) => _inicio = _cam,
        onPanUpdate: (d) {
          final i = _inicio ?? _cam;
          var yaw = i.yaw - d.delta.dx * 0.6;
          yaw = ((yaw + 540) % 360) - 180;
          final pitch = (i.pitch + d.delta.dy * 0.4).clamp(-90.0, 90.0).toDouble();
          _inicio = Camara(yaw, pitch, 1);
          widget.onCamara(_inicio!);
        },
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.white54), color: const Color(0x590A1E48)),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: painter)),
            Positioned.fill(child: CustomPaint(painter: _GuiasPainter(etiquetas))),
            for (final z in widget.zonas) _punto(z, puntos[z.id]!),
            for (final et in etiquetas) _etiqueta(et),
            Positioned(
              right: 6,
              bottom: 4,
              child: Text(
                widget.camLibre == null ? widget.vista.nombre : 'VISTA LIBRE · ${_cam.yaw.round()}°',
                style: const TextStyle(color: Color(0xFFC4D6F0), fontSize: 9, fontFamily: 'monospace'),
              ),
            ),
          ]),
        ),
      );
    });
  }

  List<_Etiqueta> _colocarEtiquetas(Size size, Map<String, Offset> puntos) {
    final problemas = widget.zonas.where((z) => z.estado != Estado.verde).toList()
      ..sort((a, b) => puntos[a.id]!.dy.compareTo(puntos[b.id]!.dy));
    final nArriba = (problemas.length / 2).ceil();
    final bandas = [problemas.take(nArriba).toList(), problemas.skip(nArriba).toList()];
    final out = <_Etiqueta>[];
    for (var bi = 0; bi < 2; bi++) {
      final banda = bandas[bi]..sort((a, b) => puntos[a.id]!.dx.compareTo(puntos[b.id]!.dx));
      for (var i = 0; i < banda.length; i++) {
        final lx = (size.width * (i + 0.5) / banda.length).clamp(54.0, size.width - 54).toDouble();
        out.add(_Etiqueta(banda[i], lx, bi == 0, puntos[banda[i].id]!, size.height));
      }
    }
    return out;
  }

  Widget _punto(Zona z, Offset p) {
    final sel = z.id == widget.seleccion;
    // Si la zona tiene pieza dibujada, la pieza ya lleva el color: el punto queda pequeño.
    final tienePieza = CarModel.instance.contornos.any((c) => c.zona == z.id);
    final tam = tienePieza ? 6.0 : 13.0;
    return Positioned(
      left: p.dx - 22,
      top: p.dy - 22,
      child: Semantics(
        button: true,
        label: '${z.nombre}: ${etiquetaEstado(z.estado)}',
        child: GestureDetector(
          onTap: () => widget.onSeleccion(z.id),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: tam,
                height: tam,
                decoration: BoxDecoration(
                  color: Colores.de(z.estado),
                  shape: BoxShape.circle,
                  border: Border.all(color: sel ? Colors.white : const Color(0xFF0A2A5E), width: tienePieza ? 1 : (sel ? 3 : 2)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _etiqueta(_Etiqueta et) {
    final sel = et.zona.id == widget.seleccion;
    return Positioned(
      left: et.lx - 52,
      top: et.arriba ? 4 : et.alto - 40,
      child: GestureDetector(
        onTap: () => widget.onSeleccion(et.zona.id),
        child: Container(
          width: 104,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xEB09285E),
            border: Border.all(color: sel ? Colors.white : Colors.white54),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(et.zona.nombre.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: Colores.de(et.zona.estado), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(etiquetaEstado(et.zona.estado), style: const TextStyle(color: Colores.linea, fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Etiqueta {
  final Zona zona;
  final double lx;
  final bool arriba;
  final Offset punto;
  final double alto;
  _Etiqueta(this.zona, this.lx, this.arriba, this.punto, this.alto);
}

class _GuiasPainter extends CustomPainter {
  final List<_Etiqueta> etiquetas;
  _GuiasPainter(this.etiquetas);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    for (final e in etiquetas) {
      final borde = e.arriba ? 40.0 : size.height - 40;
      final codo = e.arriba ? 48.0 : size.height - 48;
      final fin = e.arriba ? e.punto.dy - 9 : e.punto.dy + 9;
      canvas.drawPath(
        Path()
          ..moveTo(e.lx, borde)
          ..lineTo(e.lx, codo)
          ..lineTo(e.punto.dx, codo)
          ..lineTo(e.punto.dx, fin),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_GuiasPainter old) => true;
}

/// Miniatura de una vista, para el selector.
class MiniaturaVista extends StatelessWidget {
  final Vista vista;
  const MiniaturaVista(this.vista, {super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(50, 26),
        painter: PlanoPainter(cam: vista.cam, zonas: const [], miniatura: true, margenSup: 2, margenInf: 2),
      );
}
