import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/db.dart';
import '../data/models.dart';
import 'enciclopedia_screen.dart' show miCocheBusqueda, miCocheId;

/// Recambios del coche elegido en "Coches".
/// El MX-5 NC tiene referencias verificadas; para el resto se ofrece cada recambio
/// habitual con búsqueda directa en Oscaro para esa marca, modelo y generación.
class RecambiosScreen extends StatelessWidget {
  final String? zona;
  const RecambiosScreen({super.key, this.zona});

  static const _idConDatos = 'mazda-mx-5-nc';

  /// (categoría, recambio, zona del plano, términos de búsqueda)
  static const _catalogo = [
    ('Batería', 'Batería', 'bateria', 'batería'),
    ('Motor', 'Aceite de motor', 'motor', 'aceite motor'),
    ('Motor', 'Filtro de aceite', 'motor', 'filtro de aceite'),
    ('Motor', 'Filtro de aire', 'motor', 'filtro de aire'),
    ('Motor', 'Bujías / calentadores', 'motor', 'bujías'),
    ('Motor', 'Kit de distribución', 'motor', 'kit distribución'),
    ('Refrigeración', 'Refrigerante', 'motor', 'anticongelante refrigerante'),
    ('Refrigeración', 'Termostato', 'motor', 'termostato'),
    ('Frenos', 'Pastillas de freno', 'frenos_tras', 'pastillas de freno'),
    ('Frenos', 'Discos de freno', 'frenos_tras', 'discos de freno'),
    ('Frenos', 'Líquido de frenos', 'frenos_tras', 'líquido de frenos'),
    ('Suspensión', 'Amortiguadores delanteros', 'susp_del', 'amortiguador delantero'),
    ('Suspensión', 'Amortiguadores traseros', 'susp_tras', 'amortiguador trasero'),
    ('Dirección', 'Rótulas y bieletas', 'direccion', 'rótula dirección'),
    ('Iluminación', 'Lámparas de faros', 'faros', 'bombillas faro'),
    ('Iluminación', 'Pilotos traseros', 'pilotos', 'piloto trasero'),
    ('Neumáticos', 'Neumáticos', 'ruedas', 'neumáticos'),
    ('Escape', 'Silencioso y escape', 'escape', 'silencioso escape'),
    ('Escape', 'Sonda lambda', 'escape', 'sonda lambda'),
    ('Habitáculo', 'Filtro de habitáculo', null, 'filtro habitáculo'),
    ('Habitáculo', 'Escobillas limpiaparabrisas', null, 'escobillas limpiaparabrisas'),
  ];

  static Uri _oscaro(String q) => Uri.parse('https://www.google.com/search?q=${Uri.encodeQueryComponent('$q site:oscaro.es')}');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: miCocheId,
      builder: (context, id, _) => id == _idConDatos ? _verificados(context) : _genericos(context),
    );
  }

  Widget _aviso(String texto) => Text(texto, style: const TextStyle(fontSize: 12, color: Color(0xFFC4D6F0)));

  Widget _cabecera(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(t.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFC4D6F0))),
      );

  Widget _genericos(BuildContext context) {
    final coche = miCocheBusqueda.value;
    final hijos = <Widget>[
      Text('Recambios · $coche', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      _aviso('Cada recambio abre la búsqueda en Oscaro para este coche. Introduce allí tu matrícula para confirmar la compatibilidad exacta.'),
    ];
    String? grupo;
    for (final r in _catalogo.where((r) => zona == null || r.$3 == zona)) {
      if (r.$1 != grupo) {
        grupo = r.$1;
        hijos.add(_cabecera(r.$1));
      }
      hijos.add(Card(
        color: const Color(0x8C061E48),
        child: ListTile(
          title: Text(r.$2),
          subtitle: Text(coche),
          trailing: const Icon(Icons.open_in_new, semanticLabel: 'Buscar en Oscaro'),
          onTap: () => launchUrl(_oscaro('${r.$4} $coche'), mode: LaunchMode.externalApplication),
        ),
      ));
    }
    if (hijos.length == 3) hijos.add(const Padding(padding: EdgeInsets.only(top: 24), child: Text('Sin recambios para esta zona.')));
    return ListView(padding: const EdgeInsets.all(16), children: hijos);
  }

  Widget _verificados(BuildContext context) {
    return FutureBuilder<List<Recambio>>(
      future: AppDb.instance.recambios(zona: zona),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final lista = snap.data ?? [];
        if (lista.isEmpty) return _genericos(context);
        final hijos = <Widget>[
          Text('Recambios · ${miCocheBusqueda.value}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _aviso('Referencias verificadas para este modelo. Las equivalentes son orientativas: confirma con tu matrícula o bastidor antes de comprar.'),
        ];
        String? grupo;
        for (final r in lista) {
          if (r.categoria != grupo) {
            grupo = r.categoria;
            hijos.add(_cabecera(r.categoria));
          }
          hijos.add(Card(
            color: const Color(0x8C061E48),
            child: ListTile(
              title: Text(r.nombre),
              subtitle: Text([r.referencia, if (r.notas.isNotEmpty) r.notas].join('\n')),
              isThreeLine: r.notas.isNotEmpty,
              trailing: r.url.isEmpty ? null : const Icon(Icons.open_in_new, semanticLabel: 'Buscar en tienda'),
              onTap: r.url.isEmpty ? null : () => launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
            ),
          ));
        }
        return ListView(padding: const EdgeInsets.all(16), children: hijos);
      },
    );
  }
}
