import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Base de datos local (SQLite). Todo funciona sin conexión.
///
/// Tablas de referencia (se cargan desde assets/data/*.json):
///   zona, dtc, especificacion, mantenimiento, recambio
/// Tablas del usuario (historial propio, nunca se sobrescriben):
///   revision, lectura, dtc_detectado
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  /// Sube este número cuando cambien los JSON de referencia para recargarlos.
  static const int datosVersion = 3;

  Database? _db;
  Future<Database> get db async => _db ??= await _abrir();

  Future<Database> _abrir() async {
    final ruta = p.join(await getDatabasesPath(), 'mx5diag.db');
    final d = await openDatabase(ruta, version: 1, onCreate: (d, v) async {
      await d.execute('CREATE TABLE meta (clave TEXT PRIMARY KEY, valor TEXT)');
      await d.execute('CREATE TABLE zona (id TEXT PRIMARY KEY, nombre TEXT, x REAL, y REAL, z REAL, sistemas TEXT)');
      await d.execute('CREATE TABLE dtc (codigo TEXT PRIMARY KEY, descripcion TEXT, sistema TEXT, zona TEXT, gravedad TEXT, consejo TEXT)');
      await d.execute('CREATE TABLE especificacion (id INTEGER PRIMARY KEY AUTOINCREMENT, grupo TEXT, nombre TEXT, valor TEXT, fuente TEXT, verificado INTEGER)');
      await d.execute('CREATE TABLE mantenimiento (id TEXT PRIMARY KEY, tarea TEXT, km INTEGER, meses INTEGER, zona TEXT, fuente TEXT, verificado INTEGER, nota TEXT)');
      await d.execute('CREATE TABLE recambio (id INTEGER PRIMARY KEY AUTOINCREMENT, categoria TEXT, nombre TEXT, referencia TEXT, notas TEXT, zona TEXT, url TEXT, fuente TEXT)');
      await d.execute('CREATE TABLE revision (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, km INTEGER, zona TEXT, estado TEXT, hallazgo TEXT, accion TEXT, fuente TEXT)');
      await d.execute('CREATE TABLE lectura (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, tipo TEXT, valor REAL)');
      await d.execute('CREATE TABLE dtc_detectado (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, codigo TEXT, activo INTEGER)');
      await d.execute('CREATE TABLE tarea_hecha (id INTEGER PRIMARY KEY AUTOINCREMENT, tarea TEXT, fecha TEXT, km INTEGER)');
    });
    await _cargarReferencia(d);
    return d;
  }

  Future<void> _cargarReferencia(Database d) async {
    final r = await d.query('meta', where: 'clave = ?', whereArgs: ['datos']);
    if (r.isNotEmpty && int.parse(r.first['valor'] as String) >= datosVersion) return;

    Future<List<dynamic>> leer(String f) async => jsonDecode(await rootBundle.loadString('assets/data/$f')) as List<dynamic>;
    final zonas = await leer('zonas.json');
    final dtcs = await leer('dtc_genericos.json');
    final specs = await leer('especificaciones_nc.json');
    final mant = await leer('mantenimiento_nc.json');
    final rec = await leer('recambios_nc.json');

    await d.transaction((t) async {
      for (final tabla in ['zona', 'dtc', 'especificacion', 'mantenimiento', 'recambio']) {
        await t.delete(tabla);
      }
      final b = t.batch();
      for (final z in zonas) {
        b.insert('zona', {'id': z['id'], 'nombre': z['nombre'], 'x': z['x'], 'y': z['y'], 'z': z['z'], 'sistemas': (z['sistemas'] as List).join('|')});
      }
      for (final c in dtcs) {
        b.insert('dtc', Map<String, Object?>.from(c as Map));
      }
      for (final s in specs) {
        b.insert('especificacion', {...Map<String, Object?>.from(s as Map), 'verificado': s['verificado'] == true ? 1 : 0});
      }
      for (final m in mant) {
        b.insert('mantenimiento', {...Map<String, Object?>.from(m as Map), 'verificado': m['verificado'] == true ? 1 : 0});
      }
      for (final x in rec) {
        b.insert('recambio', Map<String, Object?>.from(x as Map));
      }
      await b.commit(noResult: true);
      await t.insert('meta', {'clave': 'datos', 'valor': '$datosVersion'}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  // ---------- Consultas de referencia ----------

  Future<List<Zona>> zonas() async => (await (await db).query('zona')).map(Zona.fromMap).toList();

  Future<Dtc> buscarDtc(String codigo) async {
    final r = await (await db).query('dtc', where: 'codigo = ?', whereArgs: [codigo.toUpperCase()]);
    return r.isEmpty ? Dtc.desconocido(codigo.toUpperCase()) : Dtc.fromMap(r.first);
  }

  Future<List<Dtc>> buscarDtcs(String texto) async {
    final q = '%${texto.trim()}%';
    final r = await (await db).query('dtc',
        where: 'codigo LIKE ? OR descripcion LIKE ? OR sistema LIKE ?', whereArgs: [q, q, q], orderBy: 'codigo', limit: 200);
    return r.map(Dtc.fromMap).toList();
  }

  Future<List<Especificacion>> especificaciones() async =>
      (await (await db).query('especificacion', orderBy: 'grupo, id')).map(Especificacion.fromMap).toList();

  Future<List<TareaMantenimiento>> mantenimiento() async =>
      (await (await db).query('mantenimiento')).map(TareaMantenimiento.fromMap).toList();

  Future<List<Recambio>> recambios({String? zona}) async => (await (await db)
          .query('recambio', where: zona == null ? null : 'zona = ?', whereArgs: zona == null ? null : [zona], orderBy: 'categoria, id'))
      .map(Recambio.fromMap)
      .toList();

  // ---------- Datos del usuario ----------

  Future<void> guardarRevision({required String zona, required Estado estado, required String hallazgo, String accion = '', String fuente = 'Revisión manual', int? km}) async {
    await (await db).insert('revision', {
      'fecha': DateTime.now().toIso8601String(),
      'km': km,
      'zona': zona,
      'estado': estado.name,
      'hallazgo': hallazgo,
      'accion': accion,
      'fuente': fuente,
    });
  }

  Future<void> guardarLectura(String tipo, double valor) async {
    await (await db).insert('lectura', {'fecha': DateTime.now().toIso8601String(), 'tipo': tipo, 'valor': valor});
  }

  Future<List<Map<String, Object?>>> lecturas(String tipo, {int limite = 60}) async =>
      (await db).query('lectura', where: 'tipo = ?', whereArgs: [tipo], orderBy: 'fecha DESC', limit: limite);

  /// Sustituye los códigos activos por los leídos ahora del coche.
  Future<void> registrarDtcs(List<String> codigos) async {
    final d = await db;
    await d.transaction((t) async {
      await t.update('dtc_detectado', {'activo': 0});
      final ahora = DateTime.now().toIso8601String();
      for (final c in codigos) {
        await t.insert('dtc_detectado', {'fecha': ahora, 'codigo': c, 'activo': 1});
      }
    });
  }

  Future<List<String>> dtcsActivos() async =>
      (await (await db).query('dtc_detectado', where: 'activo = 1')).map((r) => r['codigo'] as String).toList();

  Future<void> marcarTareaHecha(String tarea, {int? km}) async {
    await (await db).insert('tarea_hecha', {'tarea': tarea, 'fecha': DateTime.now().toIso8601String(), 'km': km});
  }

  Future<DateTime?> ultimaVezHecha(String tarea) async {
    final r = await (await db).query('tarea_hecha', where: 'tarea = ?', whereArgs: [tarea], orderBy: 'fecha DESC', limit: 1);
    return r.isEmpty ? null : DateTime.parse(r.first['fecha'] as String);
  }

  /// Estado de cada zona: combina códigos OBD activos y la última revisión manual.
  Future<List<Zona>> zonasConEstado() async {
    final d = await db;
    final zonas = await this.zonas();
    final porId = {for (final z in zonas) z.id: z};

    for (final r in await d.rawQuery('SELECT * FROM revision r WHERE fecha = (SELECT MAX(fecha) FROM revision WHERE zona = r.zona)')) {
      final z = porId[r['zona']];
      if (z == null) continue;
      z.estado = estadoDe(r['estado'] as String?);
      z.hallazgo = (r['hallazgo'] ?? '') as String;
      z.accion = (r['accion'] ?? '') as String;
      z.fuente = (r['fuente'] ?? '') as String;
    }

    for (final codigo in await dtcsActivos()) {
      final dtc = await buscarDtc(codigo);
      final z = porId[dtc.zona];
      if (z == null) continue;
      if (dtc.gravedad.index <= z.estado.index) {
        z.estado = dtc.gravedad;
        z.hallazgo = '${dtc.codigo}: ${dtc.descripcion}';
        z.accion = dtc.consejo.isEmpty ? 'Revisar en taller' : dtc.consejo;
        z.fuente = 'OBD-II';
      }
    }
    return zonas;
  }
}
