import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../obd/elm327.dart';
import '../obd/obd_parser.dart';
import '../services/bateria.dart';
import '../viewer/plano_view.dart' show Colores;

class ObdScreen extends StatefulWidget {
  final Elm327 elm;
  final VoidCallback onDatosNuevos;
  const ObdScreen({super.key, required this.elm, required this.onDatosNuevos});
  @override
  State<ObdScreen> createState() => _ObdScreenState();
}

class _ObdScreenState extends State<ObdScreen> {
  List<ScanResult> _encontrados = [];
  StreamSubscription<List<ScanResult>>? _scan;
  String _estado = 'Desconectado';
  bool _ocupado = false;
  List<Dtc> _codigos = [];
  DiagnosticoBateria? _bateria;
  final Map<String, double?> _vivo = {};
  Timer? _timerVivo;

  Elm327 get elm => widget.elm;

  Future<void> _buscar() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request();
    setState(() {
      _encontrados = [];
      _estado = 'Buscando adaptadores…';
    });
    await _scan?.cancel();
    _scan = elm.buscar().listen((r) => setState(() => _encontrados = r));
  }

  Future<void> _conectar(BluetoothDevice d) async {
    await _ocupar('Conectando con ${d.platformName}…', () async {
      await _scan?.cancel();
      await elm.conectar(d);
      _estado = 'Conectado a ${d.platformName}';
    });
  }

  Future<void> _leerCodigos() => _ocupar('Leyendo códigos…', () async {
        final c = {...await elm.leerDtcs(), ...await elm.leerDtcsPendientes()}.toList();
        await AppDb.instance.registrarDtcs(c);
        _codigos = [for (final x in c) await AppDb.instance.buscarDtc(x)];
        _estado = c.isEmpty ? 'Sin códigos de avería' : '${c.length} código(s) encontrados';
        widget.onDatosNuevos();
      });

  Future<void> _leerBateria() => _ocupar('Midiendo batería…', () async {
        final v = await elm.voltajeBateria();
        if (v == null) {
          _estado = 'El adaptador no devolvió la tensión';
          return;
        }
        final rpm = await elm.leerPid(pidsBasicos.first);
        final enMarcha = (rpm ?? 0) > 400;
        _bateria = enMarcha ? evaluarCarga(v) : evaluarReposo(v);
        await AppDb.instance.guardarLectura(enMarcha ? 'v_marcha' : 'v_reposo', v);
        await AppDb.instance.guardarRevision(
          zona: 'bateria',
          estado: _bateria!.estado,
          hallazgo: _bateria!.resumen,
          accion: _bateria!.accion,
          fuente: 'OBD-II (ATRV)',
        );
        widget.onDatosNuevos();
      });

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar códigos de avería?'),
        content: const Text('Apaga el testigo del motor y borra los datos de diagnóstico de la centralita. Hazlo solo después de reparar la avería.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    await _ocupar('Borrando…', () async {
      await elm.borrarDtcs();
      await AppDb.instance.registrarDtcs([]);
      _codigos = [];
      _estado = 'Códigos borrados';
      widget.onDatosNuevos();
    });
  }

  void _alternarVivo() {
    if (_timerVivo != null) {
      _timerVivo!.cancel();
      setState(() => _timerVivo = null);
      return;
    }
    _timerVivo = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_ocupado) return;
      _ocupado = true;
      for (final p in pidsBasicos) {
        _vivo[p.codigo] = await elm.leerPid(p);
      }
      _ocupado = false;
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _ocupar(String msg, Future<void> Function() f) async {
    setState(() {
      _ocupado = true;
      _estado = msg;
    });
    try {
      await f();
    } catch (e) {
      _estado = 'Error: $e';
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  void dispose() {
    _scan?.cancel();
    _timerVivo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(_estado, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      if (_ocupado) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      const SizedBox(height: 12),
      if (!elm.conectado) ...[
        FilledButton.icon(onPressed: _buscar, icon: const Icon(Icons.bluetooth_searching), label: const Text('Buscar adaptador OBD (BLE)')),
        const SizedBox(height: 8),
        const Text('En iPhone solo funcionan adaptadores Bluetooth LE o WiFi. Los ELM327 de Bluetooth clásico solo van en Android.',
            style: TextStyle(fontSize: 12, color: Color(0xFFC4D6F0))),
        for (final r in _encontrados)
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(r.device.platformName.isEmpty ? r.device.remoteId.str : r.device.platformName),
            subtitle: Text('Señal ${r.rssi} dBm'),
            onTap: _ocupado ? null : () => _conectar(r.device),
          ),
      ] else ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: _ocupado ? null : _leerCodigos, child: const Text('Leer códigos')),
          FilledButton(onPressed: _ocupado ? null : _leerBateria, child: const Text('Medir batería')),
          OutlinedButton(onPressed: _alternarVivo, child: Text(_timerVivo == null ? 'Datos en vivo' : 'Parar datos')),
          OutlinedButton(onPressed: _ocupado ? null : _borrar, child: const Text('Borrar códigos')),
          TextButton(
            onPressed: () async {
              _timerVivo?.cancel();
              _timerVivo = null;
              await elm.desconectar();
              setState(() => _estado = 'Desconectado');
            },
            child: const Text('Desconectar'),
          ),
        ]),
        if (_bateria != null)
          Card(
            color: const Color(0x8C061E48),
            child: ListTile(
              leading: CircleAvatar(radius: 6, backgroundColor: Colores.de(_bateria!.estado)),
              title: Text(_bateria!.resumen),
              subtitle: Text(_bateria!.accion),
            ),
          ),
        for (final d in _codigos)
          Card(
            color: const Color(0x8C061E48),
            child: ListTile(
              leading: CircleAvatar(radius: 6, backgroundColor: Colores.de(d.gravedad)),
              title: Text('${d.codigo} · ${d.descripcion}'),
              subtitle: Text(d.consejo),
            ),
          ),
        if (_timerVivo != null)
          for (final p in pidsBasicos)
            ListTile(
              dense: true,
              title: Text(p.nombre),
              trailing: Text(_vivo[p.codigo] == null ? '—' : '${_vivo[p.codigo]!.toStringAsFixed(1)} ${p.unidad}',
                  style: const TextStyle(fontFamily: 'monospace')),
            ),
      ],
    ]);
  }
}
