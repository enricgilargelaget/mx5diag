import '../data/models.dart';

/// Valoración orientativa de batería de plomo-ácido 12 V a partir de tensiones.
/// Los umbrales son habituales en taller; no sustituyen a un comprobador de carga.
class DiagnosticoBateria {
  final Estado estado;
  final String resumen;
  final String accion;
  const DiagnosticoBateria(this.estado, this.resumen, this.accion);
}

/// [reposo]: tensión con el motor parado al menos 2 h.
DiagnosticoBateria evaluarReposo(double v) {
  if (v >= 12.55) return const DiagnosticoBateria(Estado.verde, 'Carga completa', 'Ninguna');
  if (v >= 12.35) return DiagnosticoBateria(Estado.verde, 'Carga ≈75 % (${v.toStringAsFixed(2)} V)', 'Hacer un trayecto largo o cargar si el coche va a estar parado.');
  if (v >= 12.15) return DiagnosticoBateria(Estado.amarillo, 'Carga ≈50 % (${v.toStringAsFixed(2)} V)', 'Cargar con cargador de mantenimiento; vigilar si vuelve a bajar.');
  return DiagnosticoBateria(Estado.rojo, 'Batería descargada (${v.toStringAsFixed(2)} V)', 'Cargar ya; si no aguanta la carga, sustituir.');
}

/// [minimoArranque]: tensión mínima registrada durante el arranque.
DiagnosticoBateria evaluarArranque(double v) {
  if (v >= 10.0) return DiagnosticoBateria(Estado.verde, 'Arranque correcto (mín. ${v.toStringAsFixed(1)} V)', 'Ninguna');
  if (v >= 9.6) return DiagnosticoBateria(Estado.amarillo, 'Arranque justo (mín. ${v.toStringAsFixed(1)} V)', 'Batería débil: comprobar en taller y prever el cambio.');
  return DiagnosticoBateria(Estado.rojo, 'Arranque débil (mín. ${v.toStringAsFixed(1)} V)', 'Sustituir la batería.');
}

/// [enMarcha]: tensión con el motor en marcha (carga del alternador).
DiagnosticoBateria evaluarCarga(double v) {
  if (v >= 13.8 && v <= 14.7) return DiagnosticoBateria(Estado.verde, 'Alternador cargando bien (${v.toStringAsFixed(1)} V)', 'Ninguna');
  if (v > 14.7) return DiagnosticoBateria(Estado.rojo, 'Sobrecarga (${v.toStringAsFixed(1)} V)', 'Revisar regulador del alternador.');
  if (v >= 13.2) return DiagnosticoBateria(Estado.amarillo, 'Carga baja (${v.toStringAsFixed(1)} V)', 'Revisar alternador, correa y conexiones.');
  return DiagnosticoBateria(Estado.rojo, 'El alternador no carga (${v.toStringAsFixed(1)} V)', 'Revisar alternador urgentemente.');
}

/// Aviso por antigüedad (vida típica 3–5 años).
DiagnosticoBateria evaluarEdad(DateTime instalada) {
  final meses = DateTime.now().difference(instalada).inDays ~/ 30;
  if (meses < 36) return DiagnosticoBateria(Estado.verde, 'Batería de $meses meses', 'Ninguna');
  if (meses < 60) return DiagnosticoBateria(Estado.amarillo, 'Batería de $meses meses', 'Edad típica de cambio: vigilar el arranque.');
  return DiagnosticoBateria(Estado.rojo, 'Batería de $meses meses', 'Prever sustitución.');
}
