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

/// Paleta de cada situacao (IGUAL a dos alertas do site):
///   borda = faixa lateral, texto = titulo, fundo = cor clarinha do cartao
class Paleta {
  final Color borda, texto, fundo;
  const Paleta(this.borda, this.texto, this.fundo);
}

const Map<String, Paleta> paletas = {
  'conforto': Paleta(Color(0xFF3F7A4E), Color(0xFF2D5A39), Color(0xFFE6F0E8)),
  'critico_calor': Paleta(Color(0xFFB3261E), Color(0xFF8E1B14), Color(0xFFFBE9E7)),
  'atencao_calor': Paleta(Color(0xFFD9731A), Color(0xFF8A4308), Color(0xFFFDF0E3)),
  'critico_frio': Paleta(Color(0xFF1C4E80), Color(0xFF153B63), Color(0xFFE3EDF7)),
  'atencao_frio': Paleta(Color(0xFF3F8FB5), Color(0xFF1F5F7F), Color(0xFFE6F2F8)),
  'umidade_alta': Paleta(Color(0xFF1F7A74), Color(0xFF145A55), Color(0xFFE2F2F0)),
  'umidade_baixa': Paleta(Color(0xFFC29A1F), Color(0xFF6F5710), Color(0xFFF8F2DC)),
  'sem_sinal': Paleta(Color(0xFF6B7370), Color(0xFF3E4642), Color(0xFFECEBE7)),
  'sem_energia': Paleta(Color(0xFF6B3FA0), Color(0xFF4E2A7D), Color(0xFFEEE7F6)),
  'previsao_calor': Paleta(Color(0xFFD9731A), Color(0xFF8A4308), Color(0xFFFDF0E3)),
  'previsao_frio': Paleta(Color(0xFF3F8FB5), Color(0xFF1F5F7F), Color(0xFFE6F2F8)),
  'previsao_itu': Paleta(Color(0xFFB5533C), Color(0xFF8A3A26), Color(0xFFF9ECE8)),
};

const Paleta paletaNeutra = Paleta(Color(0xFF8A8F8C), Color(0xFF3E4642), Color(0xFFF1F0EC));

Paleta paletaDe(String? situacao) => paletas[situacao] ?? paletaNeutra;

/// Etiqueta escrita do alerta (alem da cor), igual ao site.
String etiquetaDe(String situacao) {
  final grupo = situacao.split('_').first;
  return switch (grupo) {
    'critico' => 'CRÍTICO',
    'previsao' => 'PREVISÃO',
    'sem' => 'FALHA',
    _ => 'ATENÇÃO',
  };
}

/// Ordem de gravidade (a cor do dia no calendario e a do pior alerta).
const List<String> gravidade = [
  'critico_calor', 'critico_frio', 'sem_energia', 'sem_sinal', 'atencao_calor', 'atencao_frio',
  'umidade_alta', 'umidade_baixa', 'previsao_itu', 'previsao_calor', 'previsao_frio',
];

Color corNivel(Nivel n) => switch (n) {
      Nivel.ok => Cores.verde,
      Nivel.aviso => const Color(0xFF9A6A12),
      Nivel.perigo => Cores.alarme,
    };
