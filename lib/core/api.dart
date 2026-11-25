// =====================================================================
// api.dart - fala com a API PHP do TECH AGROTM (a mesma do site)
// Todas as regras de negocio ficam no servidor; o app so chama as rotas.
// Assim o que aparece no app e no site e sempre igual.
// =====================================================================

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'modelos.dart';
import 'sessao.dart';

/// Erro que veio da API (ou da rede), com a mensagem pronta para a tela.
class ApiErro implements Exception {
  final String mensagem;
  final int status;      // 0 = sem conexao
  final String? codigo;  // ex.: "sem_local", "sem_chave" (rotas de clima)
  ApiErro(this.mensagem, {this.status = 0, this.codigo});
  @override
  String toString() => mensagem;
}

class Api {
  Api(this.sessao);
  final Sessao sessao;
  final http.Client _cliente = http.Client();

  /// Faz a chamada e devolve o JSON da resposta (Map, List ou null).
  Future<dynamic> _pedir(String metodo, String caminho,
      {Object? corpo, Map<String, String>? consulta}) async {
    var uri = Uri.parse(sessao.servidor + caminho);
    if (consulta != null) uri = uri.replace(queryParameters: consulta);

    final pedido = http.Request(metodo, uri);
    pedido.headers['Accept'] = 'application/json';
    final token = sessao.token;
    if (token != null) pedido.headers['Authorization'] = 'Bearer $token';
    if (corpo != null) {
      pedido.headers['Content-Type'] = 'application/json; charset=UTF-8';
      pedido.body = jsonEncode(corpo);
    }

    http.Response resposta;
    try {
      final enviado = await _cliente.send(pedido).timeout(const Duration(seconds: 60));
      resposta = await http.Response.fromStream(enviado);
    } on TimeoutException {
      // o Render gratis "dorme" e leva ~1 minuto para acordar no primeiro acesso
      throw ApiErro('O servidor demorou para responder (no Render grátis ele pode estar acordando). Tente de novo.');
    } on http.ClientException {
      throw ApiErro('Sem conexão com o servidor. Confira a internet e o endereço do servidor.');
    }

    dynamic dados;
    final texto = utf8.decode(resposta.bodyBytes, allowMalformed: true);
    if (texto.isNotEmpty) {
      try {
        dados = jsonDecode(texto);
      } catch (_) {
        dados = null;
      }
    }

    if (resposta.statusCode == 401 && sessao.token != null) {
      await sessao.sair();    // token vencido ou invalido: volta para o login
    }
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      final mapa = dados is Map ? dados : const {};
      throw ApiErro(
        (mapa['erro'] ?? 'Algo deu errado (código ${resposta.statusCode}).').toString(),
        status: resposta.statusCode,
        codigo: mapa['codigo']?.toString(),
      );
    }
    return dados;
  }

  List<Map<String, dynamic>> _lista(dynamic dados) =>
      (dados as List? ?? []).whereType<Map<String, dynamic>>().toList();

  /* ---------------- conta ---------------- */

  /// POST /login -> guarda o token na sessao
  Future<void> entrar(String email, String senha) async {
    final r = await _pedir('POST', '/login', corpo: {'email': email.trim(), 'senha': senha});
    await sessao.entrar(r['token'].toString(), (r['nome'] ?? '').toString());
  }

  /// POST /cadastro (primeiro acesso) -> ja entra
  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required String confirma,
    String telefone = '',
    String propriedade = '',
  }) async {
    final r = await _pedir('POST', '/cadastro', corpo: {
      'nome': nome.trim(),
      'email': email.trim(),
      'senha': senha,
      'senha_confirma': confirma,
      'telefone': telefone.trim(),
      'propriedade': propriedade.trim(),
    });
    await sessao.entrar(r['token'].toString(), (r['nome'] ?? nome).toString());
  }

  Future<Conta> minhaConta() async =>
      Conta.deJson(await _pedir('GET', '/perfil') as Map<String, dynamic>);

  /// PUT /perfil. Trocar e-mail ou senha exige a senha atual.
  Future<Conta> salvarConta({
    required String nome,
    required String email,
    required String telefone,
    required String propriedade,
    String senhaAtual = '',
    String senhaNova = '',
    String confirma = '',
  }) async {
    final r = await _pedir('PUT', '/perfil', corpo: {
      'nome': nome.trim(),
      'email': email.trim(),
      'telefone': telefone.trim(),
      'propriedade': propriedade.trim(),
      'senha_atual': senhaAtual,
      'senha_nova': senhaNova,
      if (senhaNova.isNotEmpty) 'senha_confirma': confirma,
    }) as Map<String, dynamic>;
    // trocar o e-mail gera um token novo
    await sessao.atualizarNome((r['nome'] ?? nome).toString(), novoToken: r['token']?.toString());
    return Conta.deJson(r);
  }

  /* ---------------- criacoes e locais ---------------- */

  /// POST /leituras/lote: leituras que o celular buscou no aparelho pelo
  /// Bluetooth (o aparelho estava sem internet). Nao precisa de login.
  Future<int> enviarLote(String serie, String perfil, List<Map<String, dynamic>> leituras) async {
    final r = await _pedir('POST', '/leituras/lote',
        corpo: {'serie': serie, 'perfil': perfil, 'conexao': 'bluetooth', 'leituras': leituras});
    return (r is Map && r['gravadas'] is num) ? (r['gravadas'] as num).toInt() : leituras.length;
  }

  /// GET /config: so para testar se o endereco do servidor esta certo.
  Future<void> testarServidor() => _pedir('GET', '/config');

  Future<List<Perfil>> perfis() async =>
      _lista(await _pedir('GET', '/perfis')).map(Perfil.deJson).toList();

  Future<List<Uf>> estados() async =>
      _lista(await _pedir('GET', '/localidades/estados')).map(Uf.deJson).toList();

  Future<List<Cidade>> cidades(String uf) async =>
      _lista(await _pedir('GET', '/localidades/estados/$uf/municipios')).map(Cidade.deJson).toList();

  /* ---------------- galpoes ---------------- */

  Future<List<Aparelho>> aparelhos() async =>
      _lista(await _pedir('GET', '/aparelhos')).map(Aparelho.deJson).toList();

  /// POST /aparelhos. Devolve um aviso (ou null) se a cidade nao foi achada.
  Future<String?> adicionarAparelho({
    required String numeroSerie,
    String apelido = '',
    required String perfil,
    int? municipio,
  }) async {
    final r = await _pedir('POST', '/aparelhos', corpo: {
      'numero_serie': numeroSerie.trim(),
      if (apelido.trim().isNotEmpty) 'apelido': apelido.trim(),
      'perfil': perfil,
      if (municipio != null) 'municipio': municipio,
    });
    return r is Map ? r['aviso']?.toString() : null;
  }

  String _serie(String s) => Uri.encodeComponent(s);

  Future<void> renomear(String serie, String apelido) =>
      _pedir('PUT', '/aparelhos/${_serie(serie)}', corpo: {'apelido': apelido.trim()});

  Future<void> trocarCriacao(String serie, String perfil) =>
      _pedir('PUT', '/aparelhos/${_serie(serie)}/perfil', corpo: {'perfil': perfil});

  Future<void> definirCidade(String serie, int municipio) =>
      _pedir('PUT', '/aparelhos/${_serie(serie)}/local', corpo: {'municipio': municipio});

  Future<void> desvincular(String serie) => _pedir('DELETE', '/aparelhos/${_serie(serie)}');

  Future<List<Leitura>> leituras(String serie, int horas) async =>
      _lista(await _pedir('GET', '/leituras/${_serie(serie)}', consulta: {'horas': '$horas'}))
          .map(Leitura.deJson)
          .toList();

  Future<List<Alerta>> alertas() async =>
      _lista(await _pedir('GET', '/alertas')).map(Alerta.deJson).toList();

  /// GET /clima/{serie}. Erros com codigo "sem_local" / "sem_chave" sao esperados.
  Future<Map<String, dynamic>> clima(String serie) async =>
      await _pedir('GET', '/clima/${_serie(serie)}') as Map<String, dynamic>;

  /* ---------------- assinatura ---------------- */

  Future<List<Plano>> planos() async =>
      _lista(await _pedir('GET', '/planos')).map(Plano.deJson).toList();

  Future<MinhasAssinaturas> minhasAssinaturas() async =>
      MinhasAssinaturas.deJson(await _pedir('GET', '/assinaturas') as Map<String, dynamic>);

  /// POST /assinaturas -> pedido pendente com o Pix copia e cola
  Future<Assinatura> comprar(int plano, int quantidade) async => Assinatura.deJson(
      await _pedir('POST', '/assinaturas', corpo: {'plano': plano, 'quantidade': quantidade})
          as Map<String, dynamic>);

  Future<void> simularPagamento(int id) => _pedir('POST', '/assinaturas/$id/confirmar');

  Future<void> cancelarPedido(int id) => _pedir('POST', '/assinaturas/$id/cancelar');
}
