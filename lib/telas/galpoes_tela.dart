// =====================================================================
// galpoes_tela.dart - lista dos galpoes com a leitura mais recente
// Atualiza sozinha a cada 15 s (igual ao painel web).
// =====================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/estado.dart';
import '../core/formatos.dart';
import '../core/modelos.dart';
import '../core/situacoes.dart';
import '../widgets/campos.dart';
import 'adicionar_galpao_tela.dart';
import 'galpao_tela.dart';

class GalpoesTela extends StatefulWidget {
  const GalpoesTela({super.key});

  @override
  State<GalpoesTela> createState() => _GalpoesTelaState();
}

class _GalpoesTelaState extends State<GalpoesTela> {
  List<Aparelho>? _lista;
  String? _erro;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _carregar();
    _relogio = Timer.periodic(const Duration(seconds: 15), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    try {
      await carregarPerfis();
      final lista = await api.aparelhos();
      if (mounted) setState(() {
        _lista = lista;
        _erro = null;
      });
    } on ApiErro catch (e) {
      if (mounted && (!silencioso || _lista == null)) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _adicionar() async {
    final adicionou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdicionarGalpaoTela()),
    );
    if (adicionou == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(sessao.nome.isEmpty ? 'Meus galpões' : 'Olá, ${sessao.nome.split(' ').first}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionar,
        backgroundColor: Cores.ambar,
        foregroundColor: Cores.grafite,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar galpão'),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _corpo(),
      ),
    );
  }

  Widget _corpo() {
    if (_lista == null && _erro == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (_erro != null) CaixaErro(_erro!),
        if (_lista != null && _lista!.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(children: [
                Text('Nenhum galpão vinculado ainda', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 6),
                Text('Adicione o aparelho com o número de série impresso na etiqueta da caixa.',
                    textAlign: TextAlign.center, style: TextStyle(color: Cores.textoSuave)),
              ]),
            ),
          ),
        for (final ap in _lista ?? <Aparelho>[]) _CartaoGalpao(ap, aoVoltar: _carregar),
      ],
    );
  }
}

class _CartaoGalpao extends StatelessWidget {
  const _CartaoGalpao(this.ap, {required this.aoVoltar});
  final Aparelho ap;
  final Future<void> Function() aoVoltar;

  @override
  Widget build(BuildContext context) {
    final sit = ap.temLeitura ? situacaoDe(ap.situacao) : null;
    final cor = sit == null ? Cores.borda : corNivel(sit.nivel);
    final perfil = perfilPorId(ap.perfil);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GalpaoTela(serie: ap.numeroSerie)));
          await aoVoltar();
        },
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: cor, width: 5))),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(ap.nome,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Icon(Icons.circle, size: 10, color: ap.online ? Cores.verde : Colors.grey),
                      const SizedBox(width: 4),
                      Text(ap.online ? 'online' : 'sem sinal',
                          style: const TextStyle(fontSize: 12, color: Cores.textoSuave)),
                    ]),
                    Text(perfil?.nome ?? ap.perfil, style: const TextStyle(fontSize: 13, color: Cores.textoSuave)),
                    const SizedBox(height: 8),
                    Text(
                      ap.temLeitura
                          ? '${numero(ap.temperatura)} °C · ${numero(ap.umidade, 0)} %'
                          : 'Aguardando a primeira leitura',
                      style: TextStyle(fontSize: ap.temLeitura ? 22 : 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      sit == null
                          ? 'Ligue o aparelho e configure o Wi-Fi pela aba Aparelho.'
                          : '${sit.texto}${ap.registradoEm != null ? ' · ${haQuanto(ap.registradoEm!)}' : ''}',
                      style: TextStyle(fontSize: 13, color: sit == null ? Cores.textoSuave : cor),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Cores.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}
