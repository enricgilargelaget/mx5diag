/// Funciones puras para interpretar respuestas del ELM327 (sin dependencias de Flutter).
library;

/// Limpia una respuesta: quita eco, "SEARCHING...", prefijos de trama ("0:", "1:") y la línea de longitud.
List<String> _lineasHex(String raw) {
  final out = <String>[];
  for (var l in raw.replaceAll('>', '').split(RegExp(r'[\r\n]+'))) {
    l = l.trim().toUpperCase();
    if (l.isEmpty || l.startsWith('SEARCHING') || l.contains('NO DATA') || l.contains('ERROR') || l.contains('UNABLE')) continue;
    l = l.replaceFirst(RegExp(r'^[0-9A-F]:\s*'), '');
    final hex = l.replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (hex.length <= 3) continue; // línea con la longitud total de una respuesta CAN multitrama
    out.add(hex);
  }
  return out;
}

List<int> _bytes(String hex) => [for (var i = 0; i + 1 < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];

/// Convierte dos bytes en un código DTC, p. ej. 0x01 0x71 → P0171.
String? bytesADtc(int a, int b) {
  if (a == 0 && b == 0) return null;
  const letras = ['P', 'C', 'B', 'U'];
  final letra = letras[(a >> 6) & 0x3];
  final d1 = (a >> 4) & 0x3;
  final resto = ((a & 0x0F) << 8 | b).toRadixString(16).toUpperCase().padLeft(3, '0');
  return '$letra$d1$resto';
}

/// Interpreta la respuesta al modo 03 (códigos almacenados) o 07 (pendientes).
/// [modo] es '43' para el 03 o '47' para el 07.
List<String> parsearDtcs(String raw, {String modo = '43'}) {
  final lineas = _lineasHex(raw);
  if (lineas.isEmpty) return [];
  final codigos = <String>{};

  final todo = lineas.join();
  final inicio = todo.indexOf(modo);
  if (inicio < 0) return [];
  var datos = _bytes(todo.substring(inicio + 2));

  // En CAN (ISO 15765) el primer byte tras 43 es el número de códigos.
  // Las respuestas multitrama ("0:", "1:") son siempre CAN y pueden llevar relleno al final.
  final multitrama = RegExp(r'(^|[\r\n])\s*[0-9A-F]:', caseSensitive: false).hasMatch(raw);
  final esCan = datos.isNotEmpty &&
      (multitrama ? datos[0] * 2 <= datos.length - 1 : (datos.length.isOdd && datos[0] * 2 == datos.length - 1));
  if (esCan) datos = datos.sublist(1, 1 + datos[0] * 2);

  // Si hay varias respuestas sin CAN, cada línea empieza con 43: procesarlas por separado.
  if (!esCan && lineas.length > 1 && lineas.every((l) => l.startsWith(modo))) {
    for (final l in lineas) {
      final b = _bytes(l.substring(2));
      for (var i = 0; i + 1 < b.length; i += 2) {
        final c = bytesADtc(b[i], b[i + 1]);
        if (c != null) codigos.add(c);
      }
    }
    return codigos.toList();
  }

  for (var i = 0; i + 1 < datos.length; i += 2) {
    final c = bytesADtc(datos[i], datos[i + 1]);
    if (c != null) codigos.add(c);
  }
  return codigos.toList();
}

/// Extrae los bytes de datos de una respuesta a un PID del modo 01 (p. ej. "41 0C 1A F8" → [0x1A, 0xF8]).
List<int>? datosPid(String raw, String pid) {
  for (final l in _lineasHex(raw)) {
    final i = l.indexOf('41${pid.toUpperCase()}');
    if (i >= 0) return _bytes(l.substring(i + 4));
  }
  return null;
}

class Pid {
  final String codigo, nombre, unidad;
  final double Function(List<int> b) formula;
  const Pid(this.codigo, this.nombre, this.unidad, this.formula);
}

final pidsBasicos = <Pid>[
  Pid('0C', 'Régimen motor', 'rpm', (b) => (b[0] * 256 + b[1]) / 4),
  Pid('0D', 'Velocidad', 'km/h', (b) => b[0].toDouble()),
  Pid('05', 'Temperatura refrigerante', '°C', (b) => b[0] - 40.0),
  Pid('0F', 'Temperatura aire admisión', '°C', (b) => b[0] - 40.0),
  Pid('04', 'Carga calculada', '%', (b) => b[0] * 100 / 255),
  Pid('11', 'Posición mariposa', '%', (b) => b[0] * 100 / 255),
  Pid('06', 'Corrección corto plazo (STFT B1)', '%', (b) => (b[0] - 128) * 100 / 128),
  Pid('07', 'Corrección largo plazo (LTFT B1)', '%', (b) => (b[0] - 128) * 100 / 128),
  Pid('10', 'Caudal de aire (MAF)', 'g/s', (b) => (b[0] * 256 + b[1]) / 100),
  Pid('42', 'Tensión módulo de control', 'V', (b) => (b[0] * 256 + b[1]) / 1000),
];

/// Lee la tensión de "ATRV" (p. ej. "12.6V").
double? parsearVoltaje(String raw) {
  final m = RegExp(r'(\d{1,2}[.,]\d)\s*V').firstMatch(raw.toUpperCase());
  return m == null ? null : double.parse(m.group(1)!.replaceAll(',', '.'));
}
