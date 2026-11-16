enum Estado { rojo, amarillo, verde }

Estado estadoDe(String? s) {
  switch (s) {
    case 'rojo':
      return Estado.rojo;
    case 'amarillo':
      return Estado.amarillo;
    default:
      return Estado.verde;
  }
}

String etiquetaEstado(Estado e) => const {
      Estado.rojo: 'Actuar ya',
      Estado.amarillo: 'Vigilar',
      Estado.verde: 'Correcto',
    }[e]!;

class Zona {
  final String id;
  final String nombre;
  final double x, y, z;
  Estado estado;
  String hallazgo;
  String accion;
  String fuente;

  Zona({
    required this.id,
    required this.nombre,
    required this.x,
    required this.y,
    required this.z,
    this.estado = Estado.verde,
    this.hallazgo = 'Sin incidencias registradas',
    this.accion = 'Ninguna',
    this.fuente = '—',
  });

  factory Zona.fromMap(Map<String, Object?> m) => Zona(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        z: (m['z'] as num).toDouble(),
      );
}

class Dtc {
  final String codigo;
  final String descripcion;
  final String sistema;
  final String zona;
  final Estado gravedad;
  final String consejo;

  Dtc(this.codigo, this.descripcion, this.sistema, this.zona, this.gravedad, this.consejo);

  factory Dtc.fromMap(Map<String, Object?> m) => Dtc(
        m['codigo'] as String,
        m['descripcion'] as String,
        (m['sistema'] ?? '') as String,
        (m['zona'] ?? 'motor') as String,
        estadoDe(m['gravedad'] as String?),
        (m['consejo'] ?? '') as String,
      );

  /// Descripción genérica para códigos que no están en la base local.
  factory Dtc.desconocido(String codigo) {
    final tipo = const {'P': 'motor/transmisión', 'C': 'chasis', 'B': 'carrocería', 'U': 'red de comunicación'}[codigo[0]] ?? '';
    final fabricante = codigo.length > 1 && codigo[1] != '0' && codigo[1] != '2';
    return Dtc(
      codigo,
      fabricante
          ? 'Código específico del fabricante ($tipo). No está en la base genérica.'
          : 'Código genérico ($tipo) no incluido aún en la base local.',
      'Desconocido',
      codigo.startsWith('C') ? 'frenos_tras' : codigo.startsWith('U') ? 'electrico' : 'motor',
      Estado.amarillo,
      'Consultar en taller o en la documentación del fabricante.',
    );
  }
}

class Especificacion {
  final String grupo, nombre, valor, fuente;
  final bool verificado;
  Especificacion(this.grupo, this.nombre, this.valor, this.fuente, this.verificado);
  factory Especificacion.fromMap(Map<String, Object?> m) => Especificacion(
      m['grupo'] as String, m['nombre'] as String, m['valor'] as String, (m['fuente'] ?? '') as String, (m['verificado'] as int) == 1);
}

class TareaMantenimiento {
  final String id, tarea, zona, fuente, nota;
  final int? km, meses;
  final bool verificado;
  TareaMantenimiento(this.id, this.tarea, this.km, this.meses, this.zona, this.fuente, this.verificado, this.nota);
  factory TareaMantenimiento.fromMap(Map<String, Object?> m) => TareaMantenimiento(
        m['id'] as String,
        m['tarea'] as String,
        m['km'] as int?,
        m['meses'] as int?,
        m['zona'] as String,
        (m['fuente'] ?? '') as String,
        (m['verificado'] as int) == 1,
        (m['nota'] ?? '') as String,
      );

  String get intervalo {
    final p = <String>[];
    if (km != null) p.add('${km! ~/ 1000}.000 km');
    if (meses != null) p.add(meses! >= 12 && meses! % 12 == 0 ? '${meses! ~/ 12} año(s)' : '$meses meses');
    return p.join(' o ');
  }
}

class Recambio {
  final String categoria, nombre, referencia, notas, zona, url, fuente;
  Recambio(this.categoria, this.nombre, this.referencia, this.notas, this.zona, this.url, this.fuente);
  factory Recambio.fromMap(Map<String, Object?> m) => Recambio(
        m['categoria'] as String,
        m['nombre'] as String,
        m['referencia'] as String,
        (m['notas'] ?? '') as String,
        m['zona'] as String,
        (m['url'] ?? '') as String,
        (m['fuente'] ?? '') as String,
      );
}
