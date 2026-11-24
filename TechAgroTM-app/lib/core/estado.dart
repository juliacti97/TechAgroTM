// =====================================================================
// estado.dart - objetos usados pelo app inteiro
// (um jeito simples, sem bibliotecas de gerenciamento de estado)
// =====================================================================

import 'api.dart';
import 'modelos.dart';
import 'sessao.dart';

final Sessao sessao = Sessao();
final Api api = Api(sessao);

/// Lista de criacoes: vem da API uma vez e fica guardada.
List<Perfil> _perfis = [];

Future<List<Perfil>> carregarPerfis() async {
  if (_perfis.isEmpty) _perfis = await api.perfis();
  return _perfis;
}

Perfil? perfilPorId(String id) {
  for (final p in _perfis) {
    if (p.id == id) return p;
  }
  return null;
}
