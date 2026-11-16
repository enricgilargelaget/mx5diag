import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../viewer/plano_view.dart' show Colores;

class CodigosScreen extends StatefulWidget {
  const CodigosScreen({super.key});
  @override
  State<CodigosScreen> createState() => _CodigosScreenState();
}

class _CodigosScreenState extends State<CodigosScreen> {
  String _q = '';
  List<Dtc> _activos = [];

  @override
  void initState() {
    super.initState();
    _cargarActivos();
  }

  Future<void> _cargarActivos() async {
    final codigos = await AppDb.instance.dtcsActivos();
    final l = <Dtc>[for (final c in codigos) await AppDb.instance.buscarDtc(c)];
    if (mounted) setState(() => _activos = l);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: const InputDecoration(labelText: 'Buscar código o avería (p. ej. P0171, sonda, batería)', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Dtc>>(
          future: AppDb.instance.buscarDtcs(_q),
          builder: (context, snap) {
            final res = snap.data ?? [];
            return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              if (_activos.isNotEmpty && _q.isEmpty) ...[
                const Text('DETECTADOS EN TU COCHE', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFC4D6F0))),
                for (final d in _activos) _fila(d),
                const Divider(),
              ],
              if (_q.isNotEmpty && res.isEmpty && RegExp(r'^[PCBU][0-9A-F]{4}$', caseSensitive: false).hasMatch(_q.trim()))
                FutureBuilder<Dtc>(future: AppDb.instance.buscarDtc(_q.trim()), builder: (c, s) => s.hasData ? _fila(s.data!) : const SizedBox()),
              for (final d in res) _fila(d),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _fila(Dtc d) => Card(
        color: const Color(0x8C061E48),
        child: ExpansionTile(
          leading: CircleAvatar(radius: 6, backgroundColor: Colores.de(d.gravedad)),
          title: Text('${d.codigo} · ${d.sistema}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          subtitle: Text(d.descripcion),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gravedad: ${etiquetaEstado(d.gravedad)} · Zona: ${d.zona}'),
            if (d.consejo.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Qué hacer: ${d.consejo}')),
          ],
        ),
      );
}
