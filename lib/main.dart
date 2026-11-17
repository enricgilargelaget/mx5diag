import 'package:flutter/material.dart';

import 'obd/elm327.dart';
import 'screens/codigos_screen.dart';
import 'screens/mantenimiento_screen.dart';
import 'screens/obd_screen.dart';
import 'screens/plano_screen.dart';
import 'screens/recambios_screen.dart';
import 'viewer/plano_view.dart' show Colores, estiloCromado;

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
            scaffoldBackgroundColor: fondo,
            colorScheme: base.colorScheme.copyWith(primary: Colores.linea, onPrimary: const Color(0xFF0A2A5E), surface: barra),
            appBarTheme: AppBarTheme(backgroundColor: fondo, elevation: 0),
            navigationBarTheme: NavigationBarThemeData(backgroundColor: barra),
          ),
          home: const Inicio(),
        );
      },
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

  static const _titulos = ['Diagnóstico de Averías Fácil', 'Códigos de avería', 'Mantenimiento', 'Recambios', 'OBD-II'];

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      PlanoScreen(key: _plano),
      const CodigosScreen(),
      const MantenimientoScreen(),
      const RecambiosScreen(),
      ObdScreen(elm: _elm, onDatosNuevos: () => _plano.currentState?.recargar()),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_titulos[_i].toUpperCase(), style: const TextStyle(fontSize: 18, letterSpacing: 0.5))),
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
          NavigationDestination(icon: Icon(Icons.build_outlined), label: 'Mantenim.'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Recambios'),
          NavigationDestination(icon: Icon(Icons.bluetooth), label: 'OBD'),
        ],
      ),
    );
  }
}
