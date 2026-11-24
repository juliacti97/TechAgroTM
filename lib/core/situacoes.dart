// =====================================================================
// situacoes.dart - nomes e cores das situacoes (iguais ao painel web)
// =====================================================================

import 'package:flutter/material.dart';

enum Nivel { ok, aviso, perigo }

class Situacao {
  final String texto;
  final Nivel nivel;
  const Situacao(this.texto, this.nivel);
}

const Map<String, Situacao> situacoes = {
  'conforto': Situacao('Ambiente ideal', Nivel.ok),
  'atencao_calor': Situacao('Acima da faixa', Nivel.aviso),
  'atencao_frio': Situacao('Abaixo da faixa', Nivel.aviso),
  'umidade_alta': Situacao('Umidade alta', Nivel.aviso),
  'umidade_baixa': Situacao('Ar seco demais', Nivel.aviso),
  'critico_calor': Situacao('Calor crítico', Nivel.perigo),
  'critico_frio': Situacao('Frio crítico', Nivel.perigo),
  'sem_sinal': Situacao('Sem sinal do aparelho', Nivel.perigo),
  'sem_energia': Situacao('Falta de energia', Nivel.perigo),
  'previsao_frio': Situacao('Previsão de frio', Nivel.aviso),
  'previsao_calor': Situacao('Previsão de calor', Nivel.aviso),
  'previsao_itu': Situacao('Previsão de calor úmido', Nivel.aviso),
};

Situacao situacaoDe(String? id) => situacoes[id] ?? Situacao(id ?? '—', Nivel.aviso);

/// Cores da marca (as mesmas do site)
class Cores {
  static const grafite = Color(0xFF1C2321);
  static const papel = Color(0xFFE9E6DE);
  static const ambar = Color(0xFFE8A33D);
  static const frio = Color(0xFF2F6F8F);
  static const alarme = Color(0xFF8C3B2E);
  static const verde = Color(0xFF3F7A4E);
  static const textoSuave = Color(0xFF5A635F);
  static const borda = Color(0xFFC8C4B8);
}

Color corNivel(Nivel n) => switch (n) {
      Nivel.ok => Cores.verde,
      Nivel.aviso => const Color(0xFF9A6A12),
      Nivel.perigo => Cores.alarme,
    };
