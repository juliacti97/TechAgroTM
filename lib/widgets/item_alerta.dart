// =====================================================================
// item_alerta.dart - um alerta compacto, com as cores do site
// (faixa lateral + fundo clarinho + etiqueta CRITICO/ATENCAO/...)
// =====================================================================

import 'package:flutter/material.dart';

import '../core/formatos.dart';
import '../core/modelos.dart';
import '../core/situacoes.dart';

class ItemAlerta extends StatelessWidget {
  const ItemAlerta(this.alerta, {super.key, this.soHora = false, this.comGalpao = false});

  final Alerta alerta;
  final bool soHora;      // na tela do calendario o dia ja esta no titulo
  final bool comGalpao;   // mostra o nome do galpao (lista de todos)

  @override
  Widget build(BuildContext context) {
    final p = paletaDe(alerta.situacao);
    final em = alerta.em;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: p.fundo,
        border: Border(left: BorderSide(color: p.borda, width: 4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: soHora ? 40 : 76,
          child: Text(em == null ? '—' : (soHora ? hora(em) : diaHora(em)),
              style: const TextStyle(fontSize: 12, color: Cores.textoSuave, fontFeatures: [FontFeature.tabularFigures()])),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(situacaoDe(alerta.situacao).texto,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: p.texto)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                color: p.texto,
                child: Text(etiquetaDe(alerta.situacao),
                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
              ),
              if (comGalpao && (alerta.apelido ?? '').isNotEmpty)
                Text('· ${alerta.apelido}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Cores.textoSuave)),
            ]),
            if (alerta.mensagem.isNotEmpty)
              Text(alerta.mensagem,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Cores.textoSuave)),
          ]),
        ),
      ]),
    );
  }
}
