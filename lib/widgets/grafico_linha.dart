// =====================================================================
// grafico_linha.dart - grafico de linha no tempo, desenhado a mao
// (CustomPainter): uma linha, a faixa ideal sombreada e as horas no eixo.
// Sem biblioteca de graficos, para o app compilar em qualquer versao.
// =====================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/formatos.dart';
import '../core/situacoes.dart';

class Ponto {
  final DateTime em;
  final double valor;
  const Ponto(this.em, this.valor);
}

class GraficoLinha extends StatelessWidget {
  const GraficoLinha({
    super.key,
    required this.pontos,
    required this.unidade,
    this.faixaMin,
    this.faixaMax,
    this.cor = Cores.ambar,
    this.altura = 200,
  });

  final List<Ponto> pontos;
  final String unidade;
  final double? faixaMin, faixaMax;   // faixa ideal (sombreada)
  final Color cor;
  final double altura;

  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) {
      return SizedBox(
        height: altura,
        child: const Center(
          child: Text('Sem leituras neste período.', style: TextStyle(color: Cores.textoSuave)),
        ),
      );
    }
    final ultimo = pontos.last;
    return Semantics(
      label: 'Gráfico com ${pontos.length} leituras. Última: ${numero(ultimo.valor)} $unidade às ${hora(ultimo.em)}.',
      child: SizedBox(
        height: altura,
        width: double.infinity,
        child: CustomPaint(
          painter: _Pintor(pontos, unidade, faixaMin, faixaMax, cor),
        ),
      ),
    );
  }
}

class _Pintor extends CustomPainter {
  _Pintor(this.pontos, this.unidade, this.faixaMin, this.faixaMax, this.cor);

  final List<Ponto> pontos;
  final String unidade;
  final double? faixaMin, faixaMax;
  final Color cor;

  static const _margemEsq = 40.0, _margemBaixo = 22.0, _margemTopo = 8.0, _margemDir = 8.0;

  @override
  void paint(Canvas canvas, Size tamanho) {
    final area = Rect.fromLTRB(_margemEsq, _margemTopo, tamanho.width - _margemDir, tamanho.height - _margemBaixo);

    // Eixo Y focado nos DADOS: antes ele ia da faixa ideal inteira (ex.: 5 a
    // 24 C para bovinos), e uma variacao de 1 grau virava uma linha reta.
    // A faixa entra no eixo so quando a borda dela esta perto dos dados.
    final dMin = pontos.map((p) => p.valor).reduce(math.min);
    final dMax = pontos.map((p) => p.valor).reduce(math.max);
    final vaoMinimo = unidade.contains('%') ? 6.0 : 2.0;   // nunca menos que 2 C / 6 %
    final vao = math.max(dMax - dMin, vaoMinimo);
    final meio = (dMin + dMax) / 2;
    final folga = vao * 0.25;
    var minY = meio - vao / 2 - folga;
    var maxY = meio + vao / 2 + folga;
    if (faixaMax != null && faixaMax! > maxY && faixaMax! - maxY <= vao) maxY = faixaMax! + folga / 2;
    if (faixaMin != null && faixaMin! < minY && minY - faixaMin! <= vao) minY = faixaMin! - folga / 2;
    final casas = (maxY - minY) < 6 ? 1 : 0;

    final t0 = pontos.first.em.millisecondsSinceEpoch.toDouble();
    var t1 = pontos.last.em.millisecondsSinceEpoch.toDouble();
    if (t1 <= t0) t1 = t0 + 60000;

    double x(DateTime d) => area.left + (d.millisecondsSinceEpoch - t0) / (t1 - t0) * area.width;
    double y(double v) => area.bottom - (v - minY) / (maxY - minY) * area.height;

    final texto = TextPainter(textDirection: TextDirection.ltr);
    void escrever(String s, Offset pos, {bool direita = false, bool centro = false}) {
      texto.text = TextSpan(text: s, style: const TextStyle(fontSize: 10, color: Cores.textoSuave));
      texto.layout();
      var dx = pos.dx;
      if (direita) dx -= texto.width;
      if (centro) dx -= texto.width / 2;
      texto.paint(canvas, Offset(dx, pos.dy - texto.height / 2));
    }

    // faixa ideal: so a parte que cabe no grafico, com as bordas marcadas
    var faixaVisivel = false;
    if (faixaMin != null && faixaMax != null && faixaMax! > minY && faixaMin! < maxY) {
      faixaVisivel = true;
      final cima = y(math.min(faixaMax!, maxY)), baixo = y(math.max(faixaMin!, minY));
      canvas.drawRect(Rect.fromLTRB(area.left, cima, area.right, baixo), Paint()..color = const Color(0x223F7A4E));
      final borda = Paint()
        ..color = const Color(0x993F7A4E)
        ..strokeWidth = 1;
      if (faixaMax! < maxY) canvas.drawLine(Offset(area.left, y(faixaMax!)), Offset(area.right, y(faixaMax!)), borda);
      if (faixaMin! > minY) canvas.drawLine(Offset(area.left, y(faixaMin!)), Offset(area.right, y(faixaMin!)), borda);
    }

    // linhas de grade + valores do eixo Y (4 divisoes)
    final grade = Paint()
      ..color = const Color(0xFFE3E0D8)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = minY + (maxY - minY) * i / 4;
      final py = y(v);
      canvas.drawLine(Offset(area.left, py), Offset(area.right, py), grade);
      escrever('${numero(v, casas)}$unidade', Offset(area.left - 4, py), direita: true);
    }

    // faixa ideal fora da escala: avisa em texto (acima ou abaixo de tudo)
    if (!faixaVisivel && faixaMin != null && faixaMax != null) {
      final acima = dMin > faixaMax!;
      escrever('${acima ? '▲ acima' : '▼ abaixo'} da faixa ideal (${numero(faixaMin!, 0)}–${numero(faixaMax!, 0)}$unidade)',
          Offset(area.left + 6, acima ? area.bottom - 9 : area.top + 9));
    }

    // horas no eixo X (inicio, meio, fim)
    for (final f in [0.0, 0.5, 1.0]) {
      final d = DateTime.fromMillisecondsSinceEpoch((t0 + (t1 - t0) * f).round());
      final rotulo = (t1 - t0) > 36 * 3600 * 1000 ? diaHora(d) : hora(d);
      escrever(rotulo, Offset(area.left + area.width * f, area.bottom + 11),
          centro: f == 0.5, direita: f == 1.0);
    }

    // a linha
    final caminho = Path();
    for (var i = 0; i < pontos.length; i++) {
      final p = Offset(x(pontos[i].em), y(pontos[i].valor));
      if (i == 0) {
        caminho.moveTo(p.dx, p.dy);
      } else {
        caminho.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      caminho,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    // ultimo ponto destacado
    final ult = pontos.last;
    canvas.drawCircle(Offset(x(ult.em), y(ult.valor)), 4, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(covariant _Pintor antigo) =>
      antigo.pontos != pontos || antigo.faixaMin != faixaMin || antigo.faixaMax != faixaMax;
}
