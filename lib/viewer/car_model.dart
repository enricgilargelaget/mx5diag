import 'dart:math' as math;

/// Punto 3D en metros. x: hacia delante, y: hacia arriba, z: hacia la izquierda.
class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);
}

/// Segmento 3D con la zona de diagnóstico a la que pertenece (null = sin zona).
typedef Seg = (V3, V3, String?);

/// Contorno cerrado de una pieza, para rellenarlo con el color de su estado.
typedef Contorno = ({String zona, List<V3> pts});

/// Modelo wireframe de un roadster genérico (diseño propio, no reproduce ningún modelo comercial).
class CarModel {
  final List<Seg> body = [];
  final List<Seg> mech = [];
  final List<Seg> wire = [];
  final List<Contorno> contornos = [];
  /// Caras de la carrocería (cuadriláteros) para el acabado cromado.
  final List<List<V3>> piel = [];
  /// Contorno del cristal del parabrisas.
  List<V3> cristal = [];
  String? _tag;

  static final CarModel instance = CarModel._build();

  CarModel._build() {
    _carroceria();
    _ruedas();
    _mecanica();
    _cableado();
  }

  static const double _pi = math.pi;

  void _l(List<Seg> a, V3 p, V3 q) => a.add((p, q, _tag));
  void _poly(List<Seg> a, List<V3> pts, {bool closed = false}) {
    for (var i = 0; i < pts.length - 1; i++) {
      _l(a, pts[i], pts[i + 1]);
    }
    if (closed) {
      _l(a, pts.last, pts.first);
      if (_tag != null) contornos.add((zona: _tag!, pts: pts));
    }
  }

  List<V3> _circ(int n, V3 Function(double c, double s) f) =>
      List.generate(n, (i) => f(math.cos(i / n * 2 * _pi), math.sin(i / n * 2 * _pi)));

  double _sp(double v, double e) => (v < 0 ? -1 : 1) * math.pow(v.abs(), e).toDouble();

  double _interp(List<List<double>> c, double x) {
    if (x >= c.first[0]) return c.first[1];
    if (x <= c.last[0]) return c.last[1];
    var i = 0;
    while (!(x <= c[i][0] && x >= c[i + 1][0])) {
      i++;
    }
    double m(int k) {
      final a = c[math.max(0, k - 1)], b = c[math.min(c.length - 1, k + 1)];
      return (b[1] - a[1]) / (b[0] - a[0]);
    }

    final h = c[i + 1][0] - c[i][0], t = (x - c[i][0]) / h, t2 = t * t, t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * c[i][1] + (t3 - 2 * t2 + t) * m(i) * h + (-2 * t3 + 3 * t2) * c[i + 1][1] + (t3 - t2) * m(i + 1) * h;
  }

  List<V3> _smooth(List<V3> pts, int n) {
    final out = <V3>[];
    double cr(double p0, double p1, double p2, double p3, double t) {
      final t2 = t * t, t3 = t2 * t;
      return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
    }

    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[math.min(pts.length - 1, i + 2)];
      for (var k = 0; k < n; k++) {
        final t = k / n;
        out.add(V3(cr(p0.x, p1.x, p2.x, p3.x, t), cr(p0.y, p1.y, p2.y, p3.y, t), cr(p0.z, p1.z, p2.z, p3.z, t)));
      }
    }
    out.add(pts.last);
    return out;
  }

  /// Perfil rectangular redondeado en el plano y-z.
  List<(double, double)> _rrect(double cy, double cz, double hy, double hz, double r) {
    final p = <(double, double)>[];
    for (var ci = 0; ci < 4; ci++) {
      final sy = ci < 2 ? 1 : -1, sz = (ci == 0 || ci == 3) ? 1 : -1;
      for (var k = 0; k <= 4; k++) {
        final a = (ci * 90 + k * 22.5) * _pi / 180;
        p.add((cy + sy * (hy - r) + r * math.sin(a), cz + sz * (hz - r) + r * math.cos(a)));
      }
    }
    return p;
  }

  void _rbox(List<Seg> arr, double x0, double x1, double y0, double y1, double z0, double z1, [double rf = 0.45]) {
    final cy = (y0 + y1) / 2, cz = (z0 + z1) / 2, hy = (y1 - y0) / 2, hz = (z1 - z0) / 2;
    final prof = _rrect(cy, cz, hy, hz, math.min(hy, hz) * rf);
    final a = prof.map((q) => V3(x0, q.$1, q.$2)).toList(), b = prof.map((q) => V3(x1, q.$1, q.$2)).toList();
    _poly(arr, a, closed: true);
    _poly(arr, b, closed: true);
    for (final k in [2, 7, 12, 17]) {
      _l(arr, a[k], b[k]);
    }
  }

  static const _top = [[2.03, .48], [1.95, .60], [1.75, .69], [1.45, .75], [1.17, .78], [0.80, .82], [0.42, .87], [0.0, .86], [-0.6, .88], [-1.16, .91], [-1.6, .92], [-1.88, .88], [-2.0, .80], [-2.04, .70]];
  static const _shy = [[2.03, .44], [1.95, .55], [1.75, .65], [1.45, .71], [1.17, .75], [0.80, .73], [0.30, .74], [-0.40, .77], [-1.16, .82], [-1.60, .81], [-1.88, .77], [-2.0, .71], [-2.04, .64]];
  static const _hw = [[2.03, .40], [1.98, .58], [1.88, .72], [1.65, .82], [1.40, .855], [1.17, .86], [0.85, .83], [0.30, .82], [-0.40, .83], [-0.90, .85], [-1.16, .86], [-1.55, .85], [-1.82, .78], [-1.97, .64], [-2.04, .42]];
  static const _sil = [[2.03, .34], [1.95, .26], [1.80, .22], [-1.75, .22], [-1.92, .27], [-2.04, .36]];
  static const _ejes = [1.17, -1.16];

  double _sill(double x) {
    var y = _interp(_sil, x);
    for (final xa in _ejes) {
      final d = x - xa;
      if (d.abs() < 0.37) y = math.max(y, .31 + math.sqrt(0.37 * 0.37 - d * d));
    }
    return y;
  }

  double _apertura(double x) {
    final u = (x + 0.09) / 0.51;
    if (u.abs() >= 1) return -1;
    return .66 * math.pow(1 - math.pow(u.abs(), 5), 0.2);
  }

  void _carroceria() {
    const ne = 4.0;
    final secs = <({List<V3?> l, List<V3?> r, List<V3>? rim})>[];
    for (var si = 0; si <= 82; si++) {
      final x = 2.03 - si * 0.0496;
      final top = _interp(_top, x), sy = _interp(_shy, x), hw = _interp(_hw, x), ow = _apertura(x);
      final sl = math.min(_sill(x), sy - .03);
      List<V3?> lado(double sd) {
        final pts = <V3?>[V3(x, sl, sd * (hw - .045)), V3(x, (sl + sy) / 2, sd * (hw - .006))];
        for (var k = 0; k <= 8; k++) {
          final ph = k / 8 * _pi / 2;
          final z = hw * math.pow(math.cos(ph), 2 / ne), y = sy + (top - sy) * math.pow(math.sin(ph), 2 / ne);
          pts.add(z < ow ? null : V3(x, y, sd * z));
        }
        return pts;
      }

      List<V3>? rim;
      if (ow > 0) {
        final cph = math.acos(math.min(1.0, math.pow(ow / hw, ne / 2).toDouble()));
        final ry = sy + (top - sy) * math.pow(math.sin(cph), 2 / ne);
        rim = [V3(x, ry, ow), V3(x, ry, -ow), V3(x, ry - .06, ow - .015), V3(x, ry - .06, -ow + .015)];
      }
      secs.add((l: lado(1), r: lado(-1), rim: rim));
    }

    for (var i = 0; i < secs.length - 1; i++) {
      for (final (a, b) in [(secs[i].l, secs[i + 1].l), (secs[i].r, secs[i + 1].r)]) {
        for (var j = 0; j < a.length - 1; j++) {
          final p0 = a[j], p1 = a[j + 1], p2 = b[j + 1], p3 = b[j];
          if (p0 != null && p1 != null && p2 != null && p3 != null) piel.add([p0, p1, p2, p3]);
        }
      }
    }

    for (var i = 0; i < secs.length; i++) {
      if (i % 4 != 0 && i != secs.length - 1) continue;
      final s = secs[i];
      for (final (side, rimIdx) in [(s.l, 0), (s.r, 1)]) {
        final run = <V3>[];
        for (final p in side) {
          if (p == null) break;
          run.add(p);
        }
        if (s.rim != null && run.length < side.length) run.add(s.rim![rimIdx]);
        _poly(body, run);
      }
    }
    for (final j in [0, 2, 4, 7, 10]) {
      for (var i = 0; i < secs.length - 1; i++) {
        for (final (a, b) in [(secs[i].l[j], secs[i + 1].l[j]), (secs[i].r[j], secs[i + 1].r[j])]) {
          if (a != null && b != null) _l(body, a, b);
        }
      }
    }
    for (var i = 0; i < secs.length - 1; i++) {
      final a = secs[i].rim, b = secs[i + 1].rim;
      if (a != null && b != null) {
        for (var k = 0; k < 4; k++) {
          _l(body, a[k], b[k]);
        }
      }
    }
    _l(body, secs.first.l[0]!, secs.first.r[0]!);
    _l(body, secs.last.l[0]!, secs.last.r[0]!);

    // Parabrisas redondeado: marco y cristal
    List<V3> parabrisas(double esc) => List.generate(48, (k) {
          final a = k / 48 * 2 * _pi;
          final u = _sp(math.cos(a), 2 / 5) * esc, v = 0.5 + 0.5 * _sp(math.sin(a), 2 / 5) * esc;
          final bow = 0.05 * (1 - u * u);
          return V3(0.42 - 0.40 * v - bow * 0.3, 0.875 + 0.31 * v + bow * 0.15, u * (0.66 - 0.06 * v));
        });
    _poly(body, parabrisas(1), closed: true);
    _poly(body, parabrisas(0.9), closed: true);
    cristal = parabrisas(0.9);

    for (final sd in [1.0, -1.0]) {
      _poly(body, List.generate(17, (k) {
        final a = k / 16 * _pi;
        return V3(-0.60, .86 + .26 * math.pow(math.sin(a), 0.6), sd * .36 + .19 * _sp(math.cos(a), 0.7));
      }));
      final hr = _rrect(1.04, sd * .36, .07, .11, .05);
      _poly(body, hr.map((q) => V3(-0.47, q.$1, q.$2)).toList(), closed: true);
      _poly(body, hr.map((q) => V3(-0.55, q.$1, q.$2)).toList(), closed: true);
      _poly(body, _circ(14, (c, s) => V3(0.33, .97 + .04 * s, sd * (.94 + .07 * c))), closed: true);
      _l(body, V3(0.34, .93, sd * .86), V3(0.33, .95, sd * .90));
    }
    _poly(body, _circ(28, (c, s) => V3(1.99 - .02 * (1 - c * c), .38 + .065 * s, .30 * c)), closed: true);

    // Bajos: suelo cerrado con esquinas redondeadas, travesaños y túnel central
    _poly(body, List.generate(64, (k) {
      final a = k / 64 * 2 * _pi;
      return V3(-0.02 + 1.86 * _sp(math.cos(a), 0.25), .20, .58 * _sp(math.sin(a), 0.25));
    }), closed: true);
    for (final xc in [1.45, 0.62, -0.35, -0.95, -1.50]) {
      _l(body, V3(xc, .20, -.56), V3(xc, .20, .56));
    }
    List<V3> tunel(double x) => [V3(x, .20, -.17), V3(x, .42, -.11), V3(x, .42, .11), V3(x, .20, .17)];
    final ta = tunel(0.45), tb = tunel(-1.0);
    _poly(body, ta);
    _poly(body, tb);
    for (var k = 0; k < 4; k++) {
      _l(body, ta[k], tb[k]);
    }
  }

  void _ruedas() {
    for (final xa in _ejes) {
      for (final sd in [1.0, -1.0]) {
        _tag = 'ruedas';
        final anillos = [(.29, .86), (.31, .83), (.31, .67), (.29, .64)]
            .map((rz) => _circ(32, (c, s) => V3(xa + rz.$1 * c, .31 + rz.$1 * s, sd * rz.$2)))
            .toList();
        for (final r in anillos) {
          _poly(body, r, closed: true);
        }
        for (var k = 0; k < 32; k += 4) {
          _poly(body, [anillos[0][k], anillos[1][k], anillos[2][k], anillos[3][k]]);
        }
        _poly(body, _circ(24, (c, s) => V3(xa + .21 * c, .31 + .21 * s, sd * .865)), closed: true);
        _poly(body, _circ(12, (c, s) => V3(xa + .05 * c, .31 + .05 * s, sd * .87)), closed: true);
        for (var k = 0; k < 5; k++) {
          final an = k / 5 * 2 * _pi;
          _l(body, V3(xa + .05 * math.cos(an), .31 + .05 * math.sin(an), sd * .87), V3(xa + .2 * math.cos(an), .31 + .2 * math.sin(an), sd * .865));
        }
        _tag = xa < 0 ? 'frenos_tras' : null;
        _poly(mech, _circ(24, (c, s) => V3(xa + .17 * c, .31 + .17 * s, sd * .70)), closed: true);
        _poly(mech, List.generate(7, (k) {
          final b = 2.1 + k * 0.12;
          return V3(xa + .19 * math.cos(b), .31 + .19 * math.sin(b), sd * .70);
        }));
        _tag = xa > 0 ? 'susp_del' : 'susp_tras';
        _poly(mech, List.generate(49, (k) {
          final t = k / 9 * 2 * _pi;
          return V3(xa + .055 * math.cos(t), .40 + .38 * k / 48, sd * .58 + .055 * math.sin(t));
        }));
        _l(mech, V3(xa, .31, sd * .62), V3(xa, .84, sd * .58));
        _poly(mech, _circ(20, (c, s) => V3(xa + .065 * c, .59 + .21 * s, sd * .58)), closed: true);
        _tag = null;
      }
    }
  }

  void _mecanica() {
    _tag = 'motor';
    _rbox(mech, 0.55, 1.05, .30, .70, -.28, .28, .35); // motor
    _rbox(mech, 0.60, 1.00, .70, .79, -.18, .18, .8); // tapa de balancines
    _tag = null;
    _rbox(mech, 1.74, 1.80, .28, .60, -.42, .42, .3); // radiador
    _tag = 'transmision';
    _rbox(mech, 0.05, 0.55, .26, .50, -.15, .15, .6); // caja de cambios
    _l(mech, const V3(0.05, .38, 0), const V3(-1.06, .36, 0)); // árbol de transmisión
    _rbox(mech, -1.26, -1.06, .24, .46, -.14, .14, .9); // diferencial
    _l(mech, const V3(-1.16, .31, .14), const V3(-1.16, .31, .65));
    _l(mech, const V3(-1.16, .31, -.14), const V3(-1.16, .31, -.65));
    _tag = null;
    _rbox(mech, -0.90, -0.64, .40, .74, -.42, .42, .5); // depósito
    _tag = 'bateria';
    _rbox(mech, 1.42, 1.64, .46, .68, -.68, -.42, .25); // batería (vano motor)
    _l(mech, const V3(1.47, .68, -.47), const V3(1.47, .71, -.47));
    _l(mech, const V3(1.59, .68, -.63), const V3(1.59, .71, -.63));
    _tag = 'escape';
    // Escape completo: colector, catalizador, tubo central por el túnel, silencioso trasero transversal y doble salida
    _poly(mech, _smooth(const [V3(0.95, .52, -.30), V3(0.80, .40, -.34), V3(0.62, .26, -.30), V3(0.45, .19, -.18)], 6));
    _rbox(mech, 0.10, 0.45, .14, .26, -.24, -.10, 1); // catalizador
    _poly(mech, _smooth(const [V3(0.10, .20, -.17), V3(-0.40, .18, -.12), V3(-1.00, .18, -.10), V3(-1.40, .19, -.10), V3(-1.58, .22, 0)], 6));
    _rbox(mech, -1.86, -1.58, .15, .31, -.56, .56, .9); // silencioso trasero
    for (final sd in [1.0, -1.0]) {
      _poly(mech, _smooth([V3(-1.86, .22, sd * .46), V3(-1.96, .22, sd * .47), V3(-2.08, .23, sd * .48)], 4));
      _poly(mech, _circ(16, (c, s) => V3(-2.08, .23 + .045 * s, sd * .48 + .045 * c)), closed: true);
      _poly(mech, _circ(16, (c, s) => V3(-2.08, .23 + .032 * s, sd * .48 + .032 * c)), closed: true);
    }
    _tag = 'motor';
    // Cárter de aceite y tapón de vaciado
    _rbox(mech, 0.58, 1.02, .17, .30, -.22, .22, .6);
    _l(mech, const V3(0.80, .17, .10), const V3(0.80, .13, .10));
    _tag = null;
    // Subchasis delantero y trasero
    _rbox(mech, 0.95, 1.40, .20, .27, -.55, .55, .5);
    _rbox(mech, -1.40, -0.95, .21, .28, -.55, .55, .5);
    _tag = 'direccion';
    _poly(mech, _circ(24, (c, s) => V3(0.05 + .04 * s, .95 + .17 * c, .36 + .17 * s)), closed: true); // volante
    _l(mech, const V3(0.05, .95, .36), const V3(1.25, .32, .36));
    _l(mech, const V3(1.25, .32, -.62), const V3(1.25, .32, .62)); // cremallera
    for (final sd in [1.0, -1.0]) {
      _tag = 'faros';
      _poly(mech, _circ(24, (c, s) {
        final xx = 1.80 + .13 * c;
        return V3(xx, .66 + (1.80 - xx) * .30, sd * (.58 + .11 * s));
      }), closed: true);
      _tag = 'pilotos';
      _poly(mech, _circ(20, (c, s) => V3(-2.0 + .015 * c, .76 + .055 * s, sd * (.55 + .11 * c))), closed: true);
      _tag = null;
      _poly(mech, _circ(16, (c, s) => V3(1.97, .30 + .035 * s, sd * (.50 + .06 * c))), closed: true);
    }
  }

  void _cableado() {
    _poly(wire, _smooth(const [V3(1.59, .71, -.63), V3(1.66, .64, -.62), V3(1.72, .66, -.62)], 6));
    _poly(wire, _smooth(const [V3(1.47, .71, -.47), V3(1.40, .66, -.20), V3(1.50, .62, .30), V3(1.72, .66, .62)], 6));
    _poly(wire, _smooth(const [V3(1.47, .71, -.47), V3(1.10, .72, -.30), V3(0.90, .74, -.15)], 6));
    _poly(wire, _smooth(const [V3(1.40, .66, -.20), V3(1.0, .40, -.60), V3(0.40, .24, -.60), V3(-1.40, .30, -.60), V3(-1.85, .70, -.50), V3(-1.98, .76, -.55)], 6));
    _poly(wire, _smooth(const [V3(-1.40, .30, -.60), V3(-1.75, .55, 0), V3(-1.98, .76, .55)], 6));
  }
}
