// =====================================================================
// alertas_tela.dart - aba "Alertas" (sino): calendario do mes + alertas
// do dia escolhido, com filtro por galpao. Igual a tela Alertas do site.
//   GET /alertas?de=&ate=&serie=&limite=2000  (um mes inteiro por vez)
// =====================================================================

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/estado.dart';
import '../core/modelos.dart';
import '../core/situacoes.dart';
import '../widgets/campos.dart';
import '../widgets/item_alerta.dart';

const _meses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
const _semana = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
const _diasSemana = ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'];

String _chave(DateTime d) => '${d.year}-${d.month}-${d.day}';

class AlertasTela extends StatefulWidget {
  const AlertasTela({super.key});

  @override
  State<AlertasTela> createState() => _AlertasTelaState();
}

class _AlertasTelaState extends State<AlertasTela> {
  late DateTime _mes;                 // dia 1 do mes mostrado
  late DateTime _dia;                 // dia escolhido
  String _serie = '';                 // '' = todos os galpoes
  List<Aparelho> _galpoes = [];
  Map<String, List<Alerta>> _porDia = {};
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _mes = DateTime(hoje.year, hoje.month);
    _dia = DateTime(hoje.year, hoje.month, hoje.day);
    _carregarGalpoes();
    _carregarMes();
  }

  Future<void> _carregarGalpoes() async {
    try {
      final l = await api.aparelhos();
      if (mounted) setState(() => _galpoes = l);
    } catch (_) {}
  }

  Future<void> _carregarMes() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await api.alertas(
        de: _mes,
        ate: DateTime(_mes.year, _mes.month + 1),
        serie: _serie,
        limite: 2000,
      );
      final porDia = <String, List<Alerta>>{};
      for (final a in lista) {
        final em = a.em?.toLocal();
        if (em != null) (porDia[_chave(em)] ??= []).add(a);
      }
      if (mounted) setState(() => _porDia = porDia);
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _trocarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _carregarMes();
  }

  String? _pior(List<Alerta> lista) {
    String? pior;
    for (final a in lista) {
      final i = gravidade.indexOf(a.situacao);
      if (i >= 0 && (pior == null || i < gravidade.indexOf(pior))) pior = a.situacao;
    }
    return pior ?? (lista.isEmpty ? null : lista.first.situacao);
  }

  @override
  Widget build(BuildContext context) {
    final doDia = _porDia[_chave(_dia)] ?? const <Alerta>[];
    final criticos = doDia.where((a) => a.situacao.startsWith('critico') || a.situacao == 'sem_energia').length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.notifications_outlined),
          SizedBox(width: 8),
          Text('Alertas'),
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: _carregarMes,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // filtro por galpao
            CampoEscolha<String>(
              rotulo: 'Galpão',
              valor: _serie,
              itens: [
                const DropdownMenuItem(value: '', child: Text('Todos os galpões')),
                for (final g in _galpoes) DropdownMenuItem(value: g.numeroSerie, child: Text(g.nome)),
              ],
              aoEscolher: (v) {
                setState(() => _serie = v ?? '');
                _carregarMes();
              },
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    IconButton(
                      tooltip: 'Mês anterior',
                      onPressed: () => _trocarMes(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text('${_meses[_mes.month - 1]} de ${_mes.year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    IconButton(
                      tooltip: 'Próximo mês',
                      onPressed: () => _trocarMes(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ]),
                  if (_carregando) const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 6),
                  _calendario(),
                  const SizedBox(height: 10),
                  _legenda(),
                ]),
              ),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_erro!, style: const TextStyle(color: Cores.alarme, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_diasSemana[_dia.weekday % 7]}, ${_dia.day} de ${_meses[_dia.month - 1].toLowerCase()} de ${_dia.year}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    doDia.isEmpty
                        ? 'Nenhum alerta neste dia. Tudo certo por aqui.'
                        : '${doDia.length} alerta(s)${criticos > 0 ? ', $criticos crítico(s)' : ''}${_serie.isEmpty ? ' em todos os galpões' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: Cores.textoSuave),
                  ),
                  const SizedBox(height: 10),
                  for (final a in doDia) ItemAlerta(a, soHora: true, comGalpao: _serie.isEmpty),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendario() {
    final primeiroDaSemana = DateTime(_mes.year, _mes.month, 1).weekday % 7;   // domingo = 0
    final diasNoMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final hoje = DateTime.now();

    final celulas = <Widget>[
      for (final s in _semana)
        Center(child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Cores.textoSuave))),
      for (var i = 0; i < primeiroDaSemana; i++) const SizedBox.shrink(),
      for (var d = 1; d <= diasNoMes; d++) _celulaDia(DateTime(_mes.year, _mes.month, d), hoje),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: celulas,
    );
  }

  Widget _celulaDia(DateTime d, DateTime hoje) {
    final lista = _porDia[_chave(d)] ?? const <Alerta>[];
    final pior = lista.isEmpty ? null : _pior(lista);
    final p = pior == null ? null : paletaDe(pior);
    final escolhido = _chave(d) == _chave(_dia);
    final ehHoje = _chave(d) == _chave(hoje);

    return Semantics(
      button: true,
      selected: escolhido,
      label: '${d.day}: ${lista.isEmpty ? 'sem alertas' : '${lista.length} alerta(s), o mais grave: ${situacaoDe(pior).texto}'}',
      child: InkWell(
        onTap: () => setState(() => _dia = d),
        child: Container(
          decoration: BoxDecoration(
            color: p?.fundo ?? Colors.white,
            border: Border.all(
              color: escolhido ? Cores.grafite : (ehHoje ? Cores.ambar : Cores.borda),
              width: escolhido || ehHoje ? 2 : 1,
            ),
          ),
          child: Stack(children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${d.day}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                if (lista.isNotEmpty)
                  Text('${lista.length}',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: p!.texto, height: 1)),
              ]),
            ),
            if (p != null)
              Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 4, color: p.borda)),
          ]),
        ),
      ),
    );
  }

  Widget _legenda() {
    const itens = [
      ('critico_calor', 'Calor crítico'),
      ('atencao_calor', 'Calor'),
      ('critico_frio', 'Frio crítico'),
      ('atencao_frio', 'Frio / previsão'),
      ('umidade_alta', 'Umidade alta'),
      ('umidade_baixa', 'Ar seco'),
      ('sem_sinal', 'Sem sinal'),
      ('sem_energia', 'Sem energia'),
    ];
    return Wrap(spacing: 10, runSpacing: 4, children: [
      for (final (sit, nome) in itens)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, color: paletaDe(sit).borda),
          const SizedBox(width: 4),
          Text(nome, style: const TextStyle(fontSize: 11, color: Cores.textoSuave)),
        ]),
    ]);
  }
}
