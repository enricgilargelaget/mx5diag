import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/db.dart';
import '../data/models.dart';

class RecambiosScreen extends StatelessWidget {
  final String? zona;
  const RecambiosScreen({super.key, this.zona});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Recambio>>(
      future: AppDb.instance.recambios(zona: zona),
      builder: (context, snap) {
        final lista = snap.data ?? [];
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (lista.isEmpty) return const Center(child: Text('Sin recambios registrados para esta zona.'));
        final hijos = <Widget>[
          const Text(
            'Las referencias equivalentes son orientativas: confirma la compatibilidad con tu matrícula o bastidor antes de comprar.',
            style: TextStyle(fontSize: 12, color: Color(0xFFC4D6F0)),
          ),
        ];
        String? grupo;
        for (final r in lista) {
          if (r.categoria != grupo) {
            grupo = r.categoria;
            hijos.add(Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Text(r.categoria.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFC4D6F0))),
            ));
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
