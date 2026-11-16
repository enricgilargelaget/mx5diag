import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'obd_parser.dart';

/// Conexión con un adaptador ELM327 por Bluetooth LE (funciona en Android e iPhone).
/// Los ELM327 de Bluetooth clásico solo funcionan en Android y no están cubiertos aquí.
class Elm327 {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _tx, _rx;
  StreamSubscription<List<int>>? _sub;
  final _buffer = StringBuffer();
  Completer<String>? _pendiente;

  bool get conectado => _device != null && _tx != null;

  /// Busca adaptadores OBD cercanos.
  Stream<List<ScanResult>> buscar({Duration duracion = const Duration(seconds: 8)}) {
    FlutterBluePlus.startScan(timeout: duracion);
    return FlutterBluePlus.scanResults.map((rs) => rs.where((r) {
          final n = (r.device.platformName + r.advertisementData.advName).toUpperCase();
          return n.contains('OBD') || n.contains('ELM') || n.contains('VLINK') || n.contains('ICAR') || n.contains('OBDLINK') || n.isNotEmpty;
        }).toList());
  }

  Future<void> conectar(BluetoothDevice d) async {
    await FlutterBluePlus.stopScan();
    await d.connect(timeout: const Duration(seconds: 12));
    final servicios = await d.discoverServices();

    // Busca una característica de escritura y otra de notificación (FFF1/FFF2, FFE1, etc.).
    for (final s in servicios) {
      for (final c in s.characteristics) {
        if (_tx == null && (c.properties.write || c.properties.writeWithoutResponse)) _tx = c;
        if (_rx == null && (c.properties.notify || c.properties.indicate)) _rx = c;
      }
      if (_tx != null && _rx != null) break;
    }
    if (_tx == null || _rx == null) {
      await d.disconnect();
      throw Exception('El adaptador no ofrece un canal serie BLE compatible.');
    }
    _device = d;
    await _rx!.setNotifyValue(true);
    _sub = _rx!.onValueReceived.listen(_recibir);

    for (final cmd in ['ATZ', 'ATE0', 'ATL0', 'ATS1', 'ATH0', 'ATSP0']) {
      await enviar(cmd, espera: cmd == 'ATZ' ? const Duration(seconds: 3) : const Duration(seconds: 2));
    }
    await enviar('0100', espera: const Duration(seconds: 8)); // fuerza la detección de protocolo
  }

  void _recibir(List<int> datos) {
    _buffer.write(latin1.decode(datos, allowInvalid: true));
    if (_buffer.toString().contains('>')) {
      final r = _buffer.toString();
      _buffer.clear();
      _pendiente?.complete(r);
      _pendiente = null;
    }
  }

  Future<String> enviar(String cmd, {Duration espera = const Duration(seconds: 4)}) async {
    if (_tx == null) throw StateError('No conectado');
    _pendiente = Completer<String>();
    _buffer.clear();
    await _tx!.write(latin1.encode('$cmd\r'), withoutResponse: _tx!.properties.writeWithoutResponse && !_tx!.properties.write);
    return _pendiente!.future.timeout(espera, onTimeout: () {
      final r = _buffer.toString();
      _buffer.clear();
      _pendiente = null;
      return r;
    });
  }

  Future<List<String>> leerDtcs() async => parsearDtcs(await enviar('03', espera: const Duration(seconds: 6)), modo: '43');
  Future<List<String>> leerDtcsPendientes() async => parsearDtcs(await enviar('07', espera: const Duration(seconds: 6)), modo: '47');

  /// Borra códigos y apaga el testigo. Solo tras reparar la avería.
  Future<void> borrarDtcs() async => enviar('04', espera: const Duration(seconds: 6));

  Future<double?> voltajeBateria() async => parsearVoltaje(await enviar('ATRV'));

  Future<double?> leerPid(Pid pid) async {
    final b = datosPid(await enviar('01${pid.codigo}'), pid.codigo);
    if (b == null || b.isEmpty) return null;
    try {
      return pid.formula(b);
    } catch (_) {
      return null;
    }
  }

  Future<void> desconectar() async {
    await _sub?.cancel();
    await _device?.disconnect();
    _device = null;
    _tx = null;
    _rx = null;
  }
}
