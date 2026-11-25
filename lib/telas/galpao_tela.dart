// =====================================================================
// galpao_tela.dart - detalhe de um galpao (igual ao painel web)
// Indicadores, graficos, criacao, clima la fora, alertas e acoes.
// =====================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/estado.dart';
import '../core/formatos.dart';
import '../core/modelos.dart';
import '../core/situacoes.dart';
import '../widgets/campos.dart';
import '../widgets/item_alerta.dart';
import '../widgets/grafico_linha.dart';
import 'bluetooth_tela.dart';
import 'seletor_cidade.dart';

class GalpaoTela extends StatefulWidget {
  const GalpaoTela({super.key, required this.serie});
  final String serie;

  @override
  State<GalpaoTela> createState() => _GalpaoTelaState();
}

class _GalpaoTelaState extends State<GalpaoTela> {
  Aparelho? _ap;
  List<Leitura> _leituras = [];
  List<Alerta> _alertas = [];
  final _rolagemAlertas = ScrollController();
  List<Perfil> _perfis = [];
  Map<String, dynamic>? _clima;
  ApiErro? _erroClima;
  String? _erro;
  int _horas = 24;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
    _relogio = Timer.periodic(const Duration(seconds: 15), (_) => _carregarDados());
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _rolagemAlertas.dispose();
    super.dispose();
  }

  Future<void> _carregarTudo() async {
    await _carregarDados();
    await _carregarClima();
  }

  /// Galpao + grafico + alertas
  Future<void> _carregarDados() async {
    try {
      final perfis = await carregarPerfis();
      final lista = await api.aparelhos();
      Aparelho? ap;
      for (final a in lista) {
        if (a.numeroSerie == widget.serie) ap = a;
      }
      if (ap == null) {
        if (mounted) setState(() => _erro = 'Este galpão não está mais na sua conta.');
        return;
      }
      final resultados = await Future.wait([api.leituras(widget.serie, _horas), api.alertas(serie: widget.serie, limite: 10)]);
      if (!mounted) return;
      setState(() {
        _ap = ap;
        _perfis = perfis;
        _leituras = resultados[0] as List<Leitura>;
        _alertas = (resultados[1] as List<Alerta>).where((a) => a.numeroSerie == widget.serie).toList();
        _erro = null;
      });
    } on ApiErro catch (e) {
      if (mounted && _ap == null) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _carregarClima() async {
    try {
      final c = await api.clima(widget.serie);
      if (mounted) setState(() {
        _clima = c;
        _erroClima = null;
      });
    } on ApiErro catch (e) {
      if (mounted) setState(() {
        _clima = null;
        _erroClima = e;
      });
    }
  }

  /* ---------------- acoes ---------------- */

  Future<void> _trocarCriacao(String? perfil) async {
    if (perfil == null || _ap == null || perfil == _ap!.perfil) return;
    try {
      await api.trocarCriacao(widget.serie, perfil);
      if (mounted) avisar(context, 'Criação alterada. O aparelho aplica em até 1 minuto.');
      await _carregarTudo();
    } on ApiErro catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  Future<void> _renomear() async {
    final campo = TextEditingController(text: _ap?.apelido ?? '');
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome do galpão'),
        content: TextField(controller: campo, maxLength: 30, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, campo.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (nome == null) return;
    if (nome.trim().length < 2) {
      if (mounted) avisar(context, 'O nome precisa de pelo menos 2 letras.');
      return;
    }
    try {
      await api.renomear(widget.serie, nome);
      await _carregarDados();
    } on ApiErro catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  Future<void> _trocarCidade() async {
    int? cidade;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cidade do galpão'),
        content: SizedBox(width: 400, child: SeletorCidade(aoEscolher: (id) => cidade = id)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) return;
    if (cidade == null) {
      if (mounted) avisar(context, 'Escolha a UF e a cidade.');
      return;
    }
    try {
      await api.definirCidade(widget.serie, cidade!);
      await _carregarTudo();
    } on ApiErro catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  Future<void> _desvincular() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular aparelho?'),
        content: Text('"${_ap?.nome}" sai da sua conta. O histórico de leituras e os alertas dele serão apagados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.alarme),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.desvincular(widget.serie);
      if (mounted) Navigator.of(context).pop();
    } on ApiErro catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  void _abrirBluetooth() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BluetoothTela(filtroSerie: _ap?.numeroSerie, perfilAtual: _ap?.perfil),
    ));
  }

  /* ---------------- tela ---------------- */

  @override
  Widget build(BuildContext context) {
    final ap = _ap;
    return Scaffold(
      appBar: AppBar(
        title: Text(ap?.nome ?? 'Galpão'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (op) {
              if (op == 'nome') _renomear();
              if (op == 'cidade') _trocarCidade();
              if (op == 'ble') _abrirBluetooth();
              if (op == 'sair') _desvincular();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'nome', child: Text('Renomear')),
              PopupMenuItem(value: 'cidade', child: Text('Trocar a cidade')),
              PopupMenuItem(value: 'ble', child: Text('Configurar por Bluetooth')),
              PopupMenuItem(value: 'sair', child: Text('Desvincular este aparelho')),
            ],
          ),
        ],
      ),
      body: ap == null
          ? Center(child: _erro != null ? Padding(padding: const EdgeInsets.all(20), child: CaixaErro(_erro!)) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregarTudo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Nº de série ${ap.numeroSerie}${ap.localNome != null ? ' · ${ap.localNome}' : ''}',
                      style: const TextStyle(color: Cores.textoSuave, fontSize: 13)),
                  const SizedBox(height: 10),
                  _indicadores(ap),
                  const SizedBox(height: 12),
                  _cartao('Criação monitorada', _seletorCriacao(ap)),
                  _cartao('Temperatura no galpão', _graficos(ap)),
                  _cartao('Clima lá fora', _blocoClima()),
                  _cartao('Últimos alertas', _listaAlertas()),
                ],
              ),
            ),
    );
  }

  Widget _cartao(String titulo, Widget filho) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            filho,
          ]),
        ),
      );

  Widget _indicadores(Aparelho ap) {
    final f = ap.faixa ?? perfilPorId(ap.perfil);
    final sit = ap.temLeitura ? situacaoDe(ap.situacao) : null;
    // Situacao com as mesmas cores dos alertas (sem sinal: cinza)
    final pal = sit == null ? null : paletaDe(ap.online ? (ap.situacao ?? 'conforto') : 'sem_sinal');
    final corSit = pal?.texto ?? Cores.textoSuave;

    Widget ind(String rotulo, String valor, String sub, Color cor, {Paleta? paleta}) => Expanded(
          child: Card(
            margin: const EdgeInsets.all(4),
            clipBehavior: Clip.antiAlias,
            color: paleta?.fundo,
            child: Container(
              decoration: paleta == null ? null : BoxDecoration(border: Border(left: BorderSide(color: paleta.borda, width: 4))),
              child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rotulo, style: const TextStyle(fontSize: 12, color: Cores.textoSuave)),
                const SizedBox(height: 2),
                Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cor)),
                Text(sub, style: const TextStyle(fontSize: 11, color: Cores.textoSuave)),
              ]),
            ),
            ),
          ),
        );

    final umidade = !ap.temLeitura
        ? '—'
        : (f != null && f.usaItu && ap.itu != null
            ? '${numero(ap.umidade, 0)} % · ITU ${numero(ap.itu, 0)}'
            : '${numero(ap.umidade, 0)} %');

    return Column(children: [
      Row(children: [
        ind('Temperatura', ap.temLeitura ? '${numero(ap.temperatura)} °C' : '—',
            f != null ? 'Faixa ${numero(f.tMin, 0)}–${numero(f.tMax, 0)} °C' : '', Cores.grafite),
        ind(f != null && f.usaItu ? 'Umidade · índice de calor' : 'Umidade', umidade,
            f != null ? 'Faixa ${numero(f.uMin, 0)}–${numero(f.uMax, 0)} %' : '', Cores.grafite),
      ]),
      Row(children: [
        ind('Situação', sit?.texto ?? 'Sem leituras', ap.textoConexao, corSit, paleta: pal),
        ind('Última leitura', ap.registradoEm != null ? haQuanto(ap.registradoEm!) : '—',
            ap.registradoEm != null ? diaHora(ap.registradoEm!) : '', Cores.grafite),
      ]),
    ]);
  }

  Widget _seletorCriacao(Aparelho ap) {
    // criacoes agrupadas na ordem: aves, suinos, bovinos, equinos
    final grupos = Perfil.nomesGrupos.keys.toList();
    final perfis = [..._perfis]..sort((a, b) {
        final ga = grupos.indexOf(a.grupo), gb = grupos.indexOf(b.grupo);
        return ga != gb ? ga.compareTo(gb) : _perfis.indexOf(a).compareTo(_perfis.indexOf(b));
      });
    final existe = perfis.any((p) => p.id == ap.perfil);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CampoEscolha<String>(
        rotulo: 'Criação',
        valor: existe ? ap.perfil : null,
        itens: [
          for (final p in perfis)
            DropdownMenuItem(
              value: p.id,
              child: Text('${Perfil.nomesGrupos[p.grupo] ?? p.grupo} · ${p.nome}', overflow: TextOverflow.ellipsis),
            ),
        ],
        aoEscolher: _trocarCriacao,
      ),
      if (ap.perfilPendente)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Aguardando o aparelho aplicar a nova criação (até 1 minuto).',
              style: TextStyle(fontSize: 12, color: Cores.textoSuave)),
        ),
    ]);
  }

  Widget _graficos(Aparelho ap) {
    final f = ap.faixa ?? perfilPorId(ap.perfil);
    const periodos = {1: '1 h', 6: '6 h', 24: '24 h', 72: '3 dias', 168: '7 dias'};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [for (final e in periodos.entries) ButtonSegment(value: e.key, label: Text(e.value))],
          selected: {_horas},
          onSelectionChanged: (s) {
            setState(() => _horas = s.first);
            _carregarDados();
          },
        ),
      ),
      const SizedBox(height: 12),
      GraficoLinha(
        pontos: [for (final l in _leituras) Ponto(l.em, l.temperatura)],
        unidade: '°',
        faixaMin: f?.tMin,
        faixaMax: f?.tMax,
        cor: Cores.ambar,
      ),
      const SizedBox(height: 14),
      const Text('Umidade no galpão', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 10),
      GraficoLinha(
        pontos: [for (final l in _leituras) Ponto(l.em, l.umidade)],
        unidade: '%',
        faixaMin: f?.uMin,
        faixaMax: f?.uMax,
        cor: Cores.frio,
        altura: 150,
      ),
      const SizedBox(height: 6),
      const Text('A faixa verde é o ideal para a criação escolhida.',
          style: TextStyle(fontSize: 12, color: Cores.textoSuave)),
    ]);
  }

  Widget _blocoClima() {
    final e = _erroClima;
    if (e != null) {
      if (e.codigo == 'sem_local') {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Informe a cidade do galpão para ver o tempo lá fora e receber avisos antes do frio ou do calor.',
              style: TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _trocarCidade, child: const Text('Escolher a cidade')),
        ]);
      }
      if (e.codigo == 'sem_chave') {
        return const Text('A previsão do tempo ainda não foi ativada neste servidor (falta a OPENWEATHER_KEY).',
            style: TextStyle(color: Cores.textoSuave));
      }
      return Text(e.mensagem, style: const TextStyle(color: Cores.textoSuave));
    }
    final c = _clima;
    if (c == null) return const Text('Carregando…', style: TextStyle(color: Cores.textoSuave));

    final a = (c['atual'] as Map?) ?? const {};
    final r = c['resumo'] as Map?;
    final avisos = (c['avisos'] as List? ?? []).whereType<Map>().toList();
    final local = (c['local'] as Map?)?['nome']?.toString() ?? '—';
    final medido = lerData(a['medido_em']);

    Widget dado(String rotulo, String valor) => SizedBox(
          width: 140,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rotulo, style: const TextStyle(fontSize: 11, color: Cores.textoSuave)),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${numero(paraDouble(a['temperatura']))} °C',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(child: Text((a['descricao'] ?? '').toString(), style: const TextStyle(color: Cores.textoSuave))),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 10, children: [
        dado('Sensação', '${numero(paraDouble(a['sensacao']))} °C'),
        dado('Umidade', '${numero(paraDouble(a['umidade']), 0)} %'),
        dado('Vento', '${numero(paraDouble(a['vento_kmh']), 0)} km/h'),
        dado('Próximas 24 h',
            r != null ? '${numero(paraDouble(r['minimo']), 0)} a ${numero(paraDouble(r['maximo']), 0)} °C' : '—'),
        dado('Chance de chuva', r != null ? '${r['chuva_maxima']} %' : '—'),
        dado('Local', local),
      ]),
      const SizedBox(height: 10),
      if (avisos.isEmpty)
        const Text('Nenhum aviso: a previsão das próximas 12 horas não pede atenção para esta criação.',
            style: TextStyle(fontSize: 12, color: Cores.textoSuave)),
      for (final av in avisos)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFFFBF0DC),
            border: Border(left: BorderSide(color: Cores.ambar, width: 3)),
          ),
          child: Text((av['mensagem'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      if (paraBool(c['desatualizado']))
        const Text('Dados do tempo temporariamente desatualizados.',
            style: TextStyle(fontSize: 12, color: Cores.textoSuave)),
      if (medido != null)
        Text('Atualizado ${haQuanto(medido)}. Fonte: OpenWeather.',
            style: const TextStyle(fontSize: 12, color: Cores.textoSuave)),
    ]);
  }

  /// Os 10 ultimos alertas, compactos, numa caixa com barra de rolagem.
  /// O historico completo, por dia, fica na aba Alertas (sino).
  Widget _listaAlertas() {
    if (_alertas.isEmpty) {
      return const Text('Nenhum alerta. Tudo certo por aqui.', style: TextStyle(color: Cores.textoSuave));
    }
    final lista = _alertas.take(10).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 250),
        child: Scrollbar(
          controller: _rolagemAlertas,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _rolagemAlertas,
            shrinkWrap: true,
            padding: const EdgeInsets.only(right: 10),
            itemCount: lista.length,
            itemBuilder: (_, i) => ItemAlerta(lista[i]),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        lista.length > 3 ? 'Role para ver os ${lista.length} últimos. Todos os alertas ficam na aba Alertas (sino).'
                         : 'Todos os alertas ficam na aba Alertas (sino).',
        style: const TextStyle(fontSize: 11.5, color: Cores.textoSuave),
      ),
    ]);
  }

}
