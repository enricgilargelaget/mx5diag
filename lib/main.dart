import 'package:flutter/material.dart';

import 'data/db.dart';
import 'obd/elm327.dart';
import 'screens/codigos_screen.dart';
import 'screens/enciclopedia_screen.dart';
import 'screens/mantenimiento_screen.dart';
import 'screens/obd_screen.dart';
import 'screens/plano_screen.dart';
import 'screens/recambios_screen.dart';
import 'viewer/plano_view.dart' show Camara, Colores, PlanoPainter, estiloCromado;

void main() => runApp(const Mx5DiagApp());

class Mx5DiagApp extends StatelessWidget {
  const Mx5DiagApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return ValueListenableBuilder<bool>(
      valueListenable: estiloCromado,
      builder: (context, cromado, _) {
        // Cromado: azul más claro y suave. Modelo 1: azul blueprint original.
        final fondo = cromado ? const Color(0xFF2F4C70) : Colores.fondo;
        final barra = cromado ? const Color(0xFF243E60) : const Color(0xFF0B2C63);
        return MaterialApp(
          title: 'Diagnóstico de Averías Fácil',
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(
            // El fondo (color, cuadrícula y marco) lo pinta el builder de abajo, detrás de todas las pantallas.
            scaffoldBackgroundColor: Colors.transparent,
            colorScheme: base.colorScheme.copyWith(primary: Colores.linea, onPrimary: const Color(0xFF0A2A5E), surface: barra),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
            navigationBarTheme: NavigationBarThemeData(backgroundColor: barra),
          ),
          builder: (context, child) => Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _FondoPainter(fondo, cromado))),
            child ?? const SizedBox(),
            const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _MarcoPainter()))),
          ]),
          home: const SplashScreen(),
        );
      },
    );
  }
}

/// Fondo de toda la app: color base, luz suave (cromado) y cuadrícula blanca tipo plano.
class _FondoPainter extends CustomPainter {
  final Color fondo;
  final bool cromado;
  const _FondoPainter(this.fondo, this.cromado);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = fondo);
    if (cromado) {
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.45),
            radius: 0.9,
            colors: [const Color(0xFF78A0CE).withOpacity(0.55), const Color(0xFF78A0CE).withOpacity(0)],
          ).createShader(r),
      );
    }
    final linea = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1;
    const paso = 18.0;
    for (double x = 0; x <= size.width; x += paso) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linea);
    }
    for (double y = 0; y <= size.height; y += paso) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linea);
    }
  }

  @override
  bool shouldRepaint(_FondoPainter old) => old.fondo != fondo || old.cromado != cromado;
}

/// Marco blanco interior a 2 mm de los bordes de la pantalla (≈ 12,6 px lógicos).
class _MarcoPainter extends CustomPainter {
  const _MarcoPainter();
  static const sangrado = 12.6;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTRB(sangrado, sangrado, size.width - sangrado, size.height - sangrado),
      Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_MarcoPainter old) => false;
}

/// Pantalla de inicio: el coche en wireframe, pequeño y latiendo, mientras se prepara la base de datos.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _latido = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future.wait([AppDb.instance.db, cargarMiCoche(), Future.delayed(const Duration(milliseconds: 2400))]).then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const Inicio(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(parent: _latido, curve: Curves.easeInOut);
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FadeTransition(
            opacity: Tween(begin: 0.65, end: 1.0).animate(curva),
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.06).animate(curva),
              child: CustomPaint(
                size: const Size(190, 100),
                painter: PlanoPainter(cam: const Camara(-35, 22, 1), zonas: const [], miniatura: true, margenSup: 4, margenInf: 4, grosor: 1.1),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('DIAGNÓSTICO DE AVERÍAS FÁCIL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 6),
          const Text('Preparando el plano…', style: TextStyle(fontSize: 12, color: Color(0xFFC4D6F0))),
        ]),
      ),
    );
  }
}

class Inicio extends StatefulWidget {
  const Inicio({super.key});
  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int _i = 0;
  final _elm = Elm327();
  final _plano = GlobalKey<PlanoScreenState>();

  void _abrirObd() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('OBD-II')),
        body: ObdScreen(elm: _elm, onDatosNuevos: () => _plano.currentState?.recargar()),
      ),
    )).then((_) {
      setState(() {});
      _plano.currentState?.recargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      PlanoScreen(key: _plano),
      const CodigosScreen(),
      const EnciclopediaScreen(),
      const MantenimientoScreen(),
      const RecambiosScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 86,
        titleSpacing: 16,
        // Título con el botón OBD debajo de la palabra "Fácil"
        title: IntrinsicWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const Text('DIAGNÓSTICO DE AVERÍAS FÁCIL', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: miCoche,
                  builder: (_, v, __) => Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFFC4D6F0))),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: _abrirObd,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), side: const BorderSide(color: Colors.white54)),
                  icon: Icon(_elm.conectado ? Icons.bluetooth_connected : Icons.bluetooth, size: 16, color: _elm.conectado ? const Color(0xFF3BE38A) : Colors.white),
                  label: const Text('OBD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
      body: IndexedStack(index: _i, children: pantallas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) {
          setState(() => _i = i);
          if (i == 0) _plano.currentState?.recargar();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), label: 'Plano'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Códigos'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Coches'),
          NavigationDestination(icon: Icon(Icons.build_outlined), label: 'Mantenim.'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Recambios'),
        ],
      ),
    );
  }
}
