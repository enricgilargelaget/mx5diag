import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../data/db.dart';

/// Coche elegido por el usuario (se muestra en la cabecera).
final miCoche = ValueNotifier<String>('Mazda MX-5 NC (2005–2015)');

/// Identificador de la generación elegida (el MX-5 NC tiene datos propios verificados).
final miCocheId = ValueNotifier<String>('mazda-mx-5-nc');

/// Texto para buscar recambios del coche elegido (marca, modelo y generación).
final miCocheBusqueda = ValueNotifier<String>('Mazda MX-5 NC');

Future<void> cargarMiCoche() async {
  final v = await AppDb.instance.meta('mi_coche');
  if (v != null) miCoche.value = v;
  miCocheId.value = await AppDb.instance.meta('mi_coche_id') ?? miCocheId.value;
  miCocheBusqueda.value = await AppDb.instance.meta('mi_coche_q') ?? miCocheBusqueda.value;
}

class Generacion {
  final String id, marca, modelo, segmento, gen, anos, motores;
  final Map<String, dynamic>? mantenimiento;
  Generacion(this.id, this.marca, this.modelo, this.segmento, this.gen, this.anos, this.motores, this.mantenimiento);
  String get titulo => '$marca $modelo $gen';
}

class Enciclopedia {
  static Future<List<Generacion>>? _cache;
  static String nota = '';

  static Future<List<Generacion>> cargar() => _cache ??= () async {
        final doc = jsonDecode(await rootBundle.loadString('assets/data/enciclopedia.json')) as Map<String, dynamic>;
        nota = (doc['nota'] ?? '') as String;
        final out = <Generacion>[];
        for (final m in doc['marcas'] as List) {
          for (final mo in m['modelos'] as List) {
            for (final g in mo['generaciones'] as List) {
              out.add(Generacion(g['id'], m['marca'], mo['modelo'], mo['segmento'], g['gen'], g['anos'], g['motores'],
                  g['mantenimiento'] as Map<String, dynamic>?));
            }
          }
        }
        return out;
      }();
}

class EnciclopediaScreen extends StatefulWidget {
  const EnciclopediaScreen({super.key});
  @override
  State<EnciclopediaScreen> createState() => _EnciclopediaScreenState();
}

class _EnciclopediaScreenState extends State<EnciclopediaScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Generacion>>(
      future: Enciclopedia.cargar(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final q = _q.trim().toLowerCase();
        final lista = snap.data!
            .where((g) => q.isEmpty || '${g.marca} ${g.modelo} ${g.gen} ${g.segmento} ${g.motores}'.toLowerCase().contains(q))
            .toList();
        final porMarca = <String, List<Generacion>>{};
        for (final g in lista) {
          porMarca.putIfAbsent(g.marca, () => []).add(g);
        }
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Buscar marca, modelo o motor', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('${porMarca.length} marcas · ${lista.length} generaciones. ${Enciclopedia.nota}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFC4D6F0))),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(12), children: [
              for (final e in porMarca.entries)
                Card(
                  color: const Color(0x8C061E48),
                  child: ExpansionTile(
                    initiallyExpanded: q.isNotEmpty,
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${e.value.map((g) => g.modelo).toSet().length} modelos'),
                    children: [
                      for (final g in e.value)
                        ListTile(
                          dense: true,
                          title: Text('${g.modelo} · ${g.gen}'),
                          subtitle: Text('${g.anos} · ${g.segmento}'),
                          trailing: Icon(g.mantenimiento != null ? Icons.verified : Icons.chevron_right,
                              size: 18, semanticLabel: g.mantenimiento != null ? 'Con mantenimiento verificado' : null),
                          onTap: () => _ficha(context, g),
                        ),
                    ],
                  ),
                ),
            ]),
          ),
        ]);
      },
    );
  }

  void _ficha(BuildContext context, Generacion g) {
    Uri buscar(String q) => Uri.parse('https://www.google.com/search?q=${Uri.encodeQueryComponent(q)}');
    final m = g.mantenimiento;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF173458),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, sc) => ListView(controller: sc, padding: const EdgeInsets.all(20), children: [
          Text(g.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          Text('${g.anos} · ${g.segmento}', style: const TextStyle(color: Color(0xFFC4D6F0))),
          const SizedBox(height: 14),
          const Text('MOTORES PRINCIPALES', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFC4D6F0))),
          Text(g.motores),
          const SizedBox(height: 14),
          const Text('MANTENIMIENTO', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFC4D6F0))),
          if (m == null)
            const Text('Pendiente de verificar para este modelo. Consulta el libro de mantenimiento o usa los botones de búsqueda.')
          else ...[
            for (final k in ['bateria', 'aceite', 'neumaticos', 'lamparas', 'refrigerante'])
              if (m[k] != null)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(const {'bateria': 'Batería', 'aceite': 'Aceite', 'neumaticos': 'Neumáticos', 'lamparas': 'Lámparas', 'refrigerante': 'Refrigerante'}[k]!),
                  subtitle: Text('${m[k]}'),
                ),
            Text(m['verificado'] == true ? 'Datos verificados' : 'Datos sin verificar', style: const TextStyle(fontSize: 12, color: Color(0xFFC4D6F0))),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              icon: const Icon(Icons.directions_car),
              label: const Text('Usar como mi coche'),
              onPressed: () async {
                final v = '${g.titulo} (${g.anos})';
                await AppDb.instance.setMeta('mi_coche', v);
                await AppDb.instance.setMeta('mi_coche_id', g.id);
                await AppDb.instance.setMeta('mi_coche_q', g.titulo);
                miCocheId.value = g.id;
                miCocheBusqueda.value = g.titulo;
                miCoche.value = v;
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.menu_book),
              label: const Text('Ficha de mantenimiento'),
              onPressed: () => launchUrl(buscar('${g.titulo} ${g.anos} capacidad aceite batería neumáticos lámparas'), mode: LaunchMode.externalApplication),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Recambios en Oscaro'),
              onPressed: () => launchUrl(buscar('${g.marca} ${g.modelo} ${g.gen} site:oscaro.es'), mode: LaunchMode.externalApplication),
            ),
          ]),
        ]),
      ),
    );
  }
}
