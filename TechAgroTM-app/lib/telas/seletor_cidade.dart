// =====================================================================
// seletor_cidade.dart - UF + cidade, com as listas vindas da API
// (as mesmas tabelas do IBGE que o site usa)
// =====================================================================

import 'package:flutter/material.dart';

import '../core/estado.dart';
import '../core/modelos.dart';
import '../widgets/campos.dart';

// listas guardadas enquanto o app esta aberto
List<Uf>? _ufs;
final Map<String, List<Cidade>> _cidades = {};

class SeletorCidade extends StatefulWidget {
  const SeletorCidade({super.key, required this.aoEscolher});
  final ValueChanged<int?> aoEscolher;

  @override
  State<SeletorCidade> createState() => _SeletorCidadeState();
}

class _SeletorCidadeState extends State<SeletorCidade> {
  String? _uf;
  int? _cidade;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    if (_ufs == null) {
      api.estados().then((l) {
        _ufs = l;
        if (mounted) setState(() {});
      }).catchError((Object _) {});
    }
  }

  Future<void> _escolherUf(String? uf) async {
    setState(() {
      _uf = uf;
      _cidade = null;
    });
    widget.aoEscolher(null);
    if (uf == null || _cidades.containsKey(uf)) return;
    setState(() => _carregando = true);
    try {
      _cidades[uf] = await api.cidades(uf);
    } catch (_) {
      // sem a lista, a cidade fica em branco (e opcional)
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cidades = _uf == null ? <Cidade>[] : (_cidades[_uf] ?? <Cidade>[]);
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: CampoEscolha<String>(
            rotulo: 'UF',
            valor: _uf,
            itens: [
              for (final u in _ufs ?? <Uf>[]) DropdownMenuItem(value: u.sigla, child: Text(u.sigla)),
            ],
            aoEscolher: _escolherUf,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CampoEscolha<int>(
            rotulo: _carregando ? 'Carregando…' : 'Cidade',
            valor: _cidade,
            itens: [
              for (final c in cidades)
                DropdownMenuItem(value: c.id, child: Text(c.nome, overflow: TextOverflow.ellipsis)),
            ],
            aoEscolher: cidades.isEmpty
                ? null
                : (v) {
                    setState(() => _cidade = v);
                    widget.aoEscolher(v);
                  },
          ),
        ),
      ],
    );
  }
}
