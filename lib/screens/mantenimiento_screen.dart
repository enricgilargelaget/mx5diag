import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/db.dart';
import '../data/models.dart';

class MantenimientoScreen extends StatefulWidget {
  const MantenimientoScreen({super.key});
  @override
  State<MantenimientoScreen> createState() => _MantenimientoScreenState();
}

class _MantenimientoScreenState extends State<MantenimientoScreen> {
  int _tick = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      key: ValueKey(_tick),
      future: Future.wait([AppDb.instance.mantenimiento(), AppDb.instance.especificaciones()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final tareas = snap.data![0] as List<TareaMantenimiento>;
        final specs = snap.data![1] as List<Especificacion>;
        final hijos = <Widget>[
          const _Titulo('PLAN DE MANTENIMIENTO'),
          for (final t in tareas) _tarea(t),
          const _Titulo('DATOS TÉCNICOS'),
          const Text('Los datos sin verificar están marcados: compruébalos en el libro de mantenimiento o en el coche.',
              style: TextStyle(fontSize: 12, color: Color(0xFFC4D6F0))),
        ];
        String? grupo;
        for (final s in specs) {
          if (s.grupo != grupo) {
            grupo = s.grupo;
            hijos.add(Padding(padding: const EdgeInsets.only(top: 12), child: Text(s.grupo, style: const TextStyle(fontWeight: FontWeight.w600))));
          }
          hijos.add(ListTile(
            dense: true,
            title: Text(s.nombre),
            subtitle: Text(s.valor),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!s.verificado) const Tooltip(message: 'Sin verificar', child: Icon(Icons.help_outline, size: 18, semanticLabel: 'Sin verificar')),
              if (s.fuente.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.link, size: 18),
                  tooltip: 'Ver fuente',
                  onPressed: () => launchUrl(Uri.parse(s.fuente), mode: LaunchMode.externalApplication),
                ),
            ]),
          ));
        }
        return ListView(padding: const EdgeInsets.all(16), children: hijos);
      },
    );
  }

  Widget _tarea(TareaMantenimiento t) => FutureBuilder<DateTime?>(
        future: AppDb.instance.ultimaVezHecha(t.id),
        builder: (context, s) {
          final ultima = s.data;
          var vence = '';
          if (ultima != null && t.meses != null) {
            final limite = DateTime(ultima.year, ultima.month + t.meses!, ultima.day);
            final dias = limite.difference(DateTime.now()).inDays;
            vence = dias < 0 ? ' · VENCIDA hace ${-dias} días' : ' · faltan $dias días';
          }
          return Card(
            color: const Color(0x8C061E48),
            child: ListTile(
              title: Text(t.tarea),
              subtitle: Text([
                'Cada ${t.intervalo}${t.verificado ? '' : ' (sin verificar)'}',
                ultima == null ? 'Sin registrar' : 'Última: ${ultima.day}/${ultima.month}/${ultima.year}$vence',
                if (t.nota.isNotEmpty) t.nota,
              ].join('\n')),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () async {
                  await AppDb.instance.marcarTareaHecha(t.id);
                  setState(() => _tick++);
                },
                child: const Text('Hecho'),
              ),
            ),
          );
        },
      );
}

class _Titulo extends StatelessWidget {
  final String t;
  const _Titulo(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFC4D6F0))),
      );
}
