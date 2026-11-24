// =====================================================================
// assinatura_tela.dart - Plano Nuvem: escolher plano -> Pix (QR Code)
// Mesmo fluxo do painel web e mesma API (/planos e /assinaturas):
// a compra feita aqui aparece no site e no dashboard do admin.
// =====================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api.dart';
import '../core/estado.dart';
import '../core/formatos.dart';
import '../core/modelos.dart';
import '../core/situacoes.dart';
import '../widgets/campos.dart';

class AssinaturaTela extends StatefulWidget {
  const AssinaturaTela({super.key});

  @override
  State<AssinaturaTela> createState() => _AssinaturaTelaState();
}

class _AssinaturaTelaState extends State<AssinaturaTela> {
  List<Plano> _planos = [];
  MinhasAssinaturas? _minhas;
  Plano? _escolhido;
  int _quantidade = 1;
  bool _ocupado = false;
  String? _erro, _ok;
  Timer? _espera;   // confere de 10 em 10 s se o Pix foi pago

  @override
  void initState() {
    super.initState();
    _carregar(primeiraVez: true);
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool primeiraVez = false}) async {
    try {
      final resultados = await Future.wait([
        _planos.isEmpty ? api.planos() : Future.value(_planos),
        api.minhasAssinaturas(),
        if (primeiraVez) api.aparelhos(),
      ]);
      if (!mounted) return;
      final antes = _minhas?.pendente;
      final minhas = resultados[1] as MinhasAssinaturas;
      setState(() {
        _planos = resultados[0] as List<Plano>;
        _minhas = minhas;
        if (primeiraVez) {
          final n = (resultados[2] as List).length;
          _quantidade = n < 1 ? 1 : n;
        }
        // estava esperando e o pedido foi pago (simulado ou confirmado no admin)
        if (antes != null && minhas.pendente == null) {
          final ultimo = minhas.historico.isNotEmpty ? minhas.historico.first : null;
          if (ultimo != null && ultimo.status == 'ativa' && ultimo.id == antes.id) {
            _ok = 'Pagamento confirmado! Pedido nº ${ultimo.id} ativo até ${ultimo.fim != null ? dia(ultimo.fim!) : '—'}.';
            _escolhido = null;
          }
        }
      });
      _ajustarEspera();
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  void _ajustarEspera() {
    if (_minhas?.pendente != null) {
      _espera ??= Timer.periodic(const Duration(seconds: 10), (_) => _carregar());
    } else {
      _espera?.cancel();
      _espera = null;
    }
  }

  Future<void> _acao(Future<void> Function() fazer) async {
    setState(() {
      _ocupado = true;
      _erro = null;
      _ok = null;
    });
    try {
      await fazer();
      await _carregar();
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _gerarPix() => _acao(() async {
        await api.comprar(_escolhido!.id, _quantidade);
      });

  void _simular(int id) => _acao(() => api.simularPagamento(id));

  Future<void> _cancelar(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar este pedido?'),
        content: const Text('O QR Code deixa de valer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar pedido')),
        ],
      ),
    );
    if (ok == true) _acao(() => api.cancelarPedido(id));
  }

  @override
  Widget build(BuildContext context) {
    final m = _minhas;
    return Scaffold(
      appBar: AppBar(title: const Text('Assinatura Plano Nuvem')),
      body: m == null && _erro == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_erro != null) CaixaErro(_erro!),
                  if (_ok != null) CaixaOk(_ok!),
                  if (m != null) _status(m),
                  const SizedBox(height: 12),
                  if (m != null && m.pendente != null) _pix(m.pendente!, m.pagamentoSimulado) else ..._compra(),
                  const SizedBox(height: 20),
                  const Text('Histórico', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (m == null || m.historico.isEmpty)
                    const Text('Nenhuma compra ainda.', style: TextStyle(color: Cores.textoSuave)),
                  for (final a in m?.historico ?? <Assinatura>[]) _itemHistorico(a),
                ],
              ),
            ),
    );
  }

  Widget _status(MinhasAssinaturas m) {
    final a = m.atual;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: a != null ? Cores.verde : Cores.borda, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a != null ? '${a.plano} ativo' : 'Você está no plano gratuito',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            a != null
                ? '${a.quantidade} aparelho(s) · válido de ${a.inicio != null ? dia(a.inicio!) : '—'} até ${a.fim != null ? dia(a.fim!) : '—'}. Comprar de novo renova a partir do fim.'
                : '30 dias de histórico e notificação pelo aplicativo. O Plano Nuvem guarda 5 anos e avisa por SMS e WhatsApp.',
            style: const TextStyle(color: Cores.textoSuave),
          ),
        ]),
      ),
    );
  }

  List<Widget> _compra() {
    final total = _escolhido == null ? null : _escolhido!.preco * _quantidade;
    return [
      const Text('Escolha o plano', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 8),
      for (final p in _planos)
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _escolhido?.id == p.id ? Cores.grafite : Colors.transparent, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _escolhido = p),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  '${reais(p.preco)} ${p.meses > 1 ? '/ ${p.meses} meses' : '/ mês'}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                Text(
                  p.meses > 1 ? '${reais(p.preco / p.meses)}/mês por aparelho' : 'por mês, por aparelho',
                  style: const TextStyle(fontSize: 12, color: Cores.textoSuave),
                ),
                if (p.descricao.isNotEmpty)
                  Text(p.descricao, style: const TextStyle(fontSize: 13, color: Cores.textoSuave)),
              ]),
            ),
          ),
        ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              const Expanded(child: Text('Aparelhos', style: TextStyle(fontWeight: FontWeight.w600))),
              IconButton(
                onPressed: _quantidade > 1 ? () => setState(() => _quantidade--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_quantidade', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: _quantidade < 100 ? () => setState(() => _quantidade++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
            const Divider(),
            Row(children: [
              const Expanded(child: Text('Total a pagar', style: TextStyle(color: Cores.textoSuave))),
              Text(total == null ? 'Escolha um plano' : reais(total),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Cores.ambar,
                foregroundColor: Cores.grafite,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _escolhido == null || _ocupado ? null : _gerarPix,
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Pagar com Pix', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    ];
  }

  Widget _pix(Assinatura pedido, bool simulado) {
    final codigo = pedido.pixCopiaCola ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (simulado)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                color: Cores.ambar,
                child: const Text('QR CODE DE DEMONSTRAÇÃO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
          const SizedBox(height: 8),
          Text('Pague ${reais(pedido.valor)} com Pix',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text('${pedido.plano}, ${pedido.quantidade} aparelho(s) · pedido nº ${pedido.id}',
              style: const TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 12),
          if (codigo.isNotEmpty)
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: codigo, version: QrVersions.auto, size: 240),
              ),
            ),
          const SizedBox(height: 12),
          const Text('1. Abra o app do seu banco e escolha Pix.\n'
              '2. Leia o QR Code ou cole o código abaixo.\n'
              '3. Confira o valor e confirme.',
              style: TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFFF4F2EC),
            child: SelectableText(codigo, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: codigo));
                if (mounted) avisar(context, 'Código Pix copiado.');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar código'),
            ),
            if (simulado)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Cores.ambar, foregroundColor: Cores.grafite),
                onPressed: _ocupado ? null : () => _simular(pedido.id),
                child: const Text('Simular pagamento'),
              ),
            TextButton(
              onPressed: _ocupado ? null : () => _cancelar(pedido.id),
              child: const Text('Cancelar pedido'),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('Esta tela confere sozinha, a cada 10 segundos, se o pagamento chegou.',
              style: TextStyle(fontSize: 12, color: Cores.textoSuave)),
        ]),
      ),
    );
  }

  Widget _itemHistorico(Assinatura a) {
    final cor = switch (a.status) {
      'ativa' => Cores.verde,
      'pendente' => const Color(0xFF9A6A12),
      'cancelada' => Cores.alarme,
      _ => Cores.textoSuave,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('#${a.id} · ${a.plano}'),
        subtitle: Text(
          '${a.quantidade} aparelho(s) · ${reais(a.valor)}'
          '${a.inicio != null ? '\n${dia(a.inicio!)} a ${a.fim != null ? dia(a.fim!) : '—'}' : ''}',
        ),
        isThreeLine: a.inicio != null,
        trailing: Text(a.nomeStatus, style: TextStyle(color: cor, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
