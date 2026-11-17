import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../viewer/plano_view.dart';
import 'recambios_screen.dart';

class PlanoScreen extends StatefulWidget {
  const PlanoScreen({super.key});
  @override
  State<PlanoScreen> createState() => PlanoScreenState();
}

class PlanoScreenState extends State<PlanoScreen> {
  List<Zona> _zonas = [];
  String? _sel;
  Vista _vista = vistas.first;
  Camara? _libre;
  bool _meca = true, _cable = true;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    final z = await AppDb.instance.zonasConEstado();
    if (!mounted) return;
    setState(() {
      _zonas = z;
      _sel ??= (z.where((e) => e.estado != Estado.verde).toList()..sort((a, b) => a.estado.index.compareTo(b.estado.index)))
              .map((e) => e.id)
              .firstOrNull ??
          (z.isEmpty ? null : z.first.id);
    });
  }

  int _cuenta(Estado e) => _zonas.where((z) => z.estado == e).length;

  @override
  Widget build(BuildContext context) {
    final sel = _zonas.where((z) => z.id == _sel).firstOrNull;
    final lista = [..._zonas]..sort((a, b) => a.estado.index.compareTo(b.estado.index));
    return RefreshIndicator(
      onRefresh: recargar,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        Row(children: [
          for (final e in Estado.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _Chip('${_cuenta(e)} ${etiquetaEstado(e).toLowerCase()}', Colores.de(e), Colores.tinta(e)),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (final v in vistas)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => setState(() {
                    _vista = v;
                    _libre = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: v == _vista && _libre == null ? Colors.white : Colors.white38),
                      borderRadius: BorderRadius.circular(4),
                      color: v == _vista && _libre == null ? Colors.white24 : const Color(0x730A1E48),
                    ),
                    child: Column(children: [
                      MiniaturaVista(v),
                      Text(v.etiqueta.toUpperCase(), style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text('GIRAR', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFC4D6F0))),
          Expanded(
            child: Slider(
              min: -180,
              max: 180,
              value: (_libre ?? _vista.cam).yaw.clamp(-180, 180).toDouble(),
              onChanged: (y) => setState(() => _libre = Camara(y, (_libre ?? _vista.cam).pitch, 1)),
            ),
          ),
          FilterChip(label: const Text('Mecánica'), selected: _meca, onSelected: (v) => setState(() => _meca = v)),
          const SizedBox(width: 6),
          FilterChip(label: const Text('Cableado'), selected: _cable, onSelected: (v) => setState(() => _cable = v)),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              estiloCromado.value = !estiloCromado.value;
            }),
            child: Text(estiloCromado.value ? 'Ver Modelo 1' : 'Ver cromado'),
          ),
        ),
        SizedBox(
          height: 330,
          child: PlanoView(
            zonas: _zonas,
            seleccion: _sel,
            onSeleccion: (id) => setState(() => _sel = id),
            vista: _vista,
            camLibre: _libre,
            onCamara: (c) => setState(() => _libre = c),
            mecanica: _meca,
            cableado: _cable,
            cromado: estiloCromado.value,
          ),
        ),
        const SizedBox(height: 12),
        if (sel != null) _Ficha(zona: sel, onCambio: recargar),
        const SizedBox(height: 12),
        const Text('TODAS LAS ZONAS', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFC4D6F0))),
        const SizedBox(height: 6),
        for (final z in lista)
          Card(
            color: const Color(0x8C061E48),
            shape: RoundedRectangleBorder(side: BorderSide(color: z.id == _sel ? Colors.white : Colors.white24), borderRadius: BorderRadius.circular(4)),
            child: ListTile(
              onTap: () => setState(() => _sel = z.id),
              leading: CircleAvatar(radius: 5, backgroundColor: Colores.de(z.estado)),
              title: Text(z.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(z.hallazgo, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: _Chip(etiquetaEstado(z.estado), Colores.de(z.estado), Colores.tinta(z.estado)),
            ),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final Color fondo, tinta;
  const _Chip(this.texto, this.fondo, this.tinta);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(4)),
        child: Text(texto, style: TextStyle(color: tinta, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _Ficha extends StatelessWidget {
  final Zona zona;
  final Future<void> Function() onCambio;
  const _Ficha({required this.zona, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(4), color: const Color(0x8C061E48)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(zona.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
          _Chip(etiquetaEstado(zona.estado), Colores.de(zona.estado), Colores.tinta(zona.estado)),
        ]),
        const SizedBox(height: 8),
        Text(zona.hallazgo, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        const Text('ACCIÓN RECOMENDADA', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFFC4D6F0))),
        Text(zona.accion, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 6),
        Text('Fuente: ${zona.fuente}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFC4D6F0))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () async {
                if (await _dialogoRevision(context, zona)) await onCambio();
              },
              child: const Text('Registrar revisión'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(appBar: AppBar(title: Text('Recambios · ${zona.nombre}')), body: RecambiosScreen(zona: zona.id)),
              )),
              child: const Text('Recambios'),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<bool> _dialogoRevision(BuildContext context, Zona z) async {
    var estado = Estado.verde;
    final hallazgo = TextEditingController(), accion = TextEditingController(), km = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Revisión · ${z.nombre}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<Estado>(
                segments: [for (final e in Estado.values) ButtonSegment(value: e, label: Text(etiquetaEstado(e)))],
                selected: {estado},
                onSelectionChanged: (s) => set(() => estado = s.first),
              ),
              TextField(controller: hallazgo, decoration: const InputDecoration(labelText: 'Qué has visto')),
              TextField(controller: accion, decoration: const InputDecoration(labelText: 'Acción a tomar')),
              TextField(controller: km, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kilómetros (opcional)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return false;
    await AppDb.instance.guardarRevision(
      zona: z.id,
      estado: estado,
      hallazgo: hallazgo.text.isEmpty ? 'Revisado' : hallazgo.text,
      accion: accion.text.isEmpty ? 'Ninguna' : accion.text,
      km: int.tryParse(km.text),
    );
    return true;
  }
}
