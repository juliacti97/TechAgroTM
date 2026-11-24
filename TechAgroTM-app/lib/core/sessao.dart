// =====================================================================
// sessao.dart - quem esta logado e qual servidor usar
// Guarda no celular (SharedPreferences) o token, o nome e o endereco
// da API, para o app abrir ja logado na proxima vez.
// =====================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class Sessao extends ChangeNotifier {
  static const _chToken = 'agrotm_token';
  static const _chNome = 'agrotm_nome';
  static const _chServidor = 'agrotm_servidor';

  String? token;
  String nome = '';
  String servidor = servidorPadrao;

  bool get logado => token != null && !_tokenVencido(token!);

  Future<void> carregar() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_chToken);
    nome = p.getString(_chNome) ?? '';
    servidor = p.getString(_chServidor) ?? servidorPadrao;
    if (token != null && _tokenVencido(token!)) {
      token = null;
      await p.remove(_chToken);
    }
    notifyListeners();
  }

  Future<void> entrar(String novoToken, String novoNome) async {
    token = novoToken;
    nome = novoNome;
    final p = await SharedPreferences.getInstance();
    await p.setString(_chToken, novoToken);
    await p.setString(_chNome, novoNome);
    notifyListeners();
  }

  Future<void> atualizarNome(String novoNome, {String? novoToken}) async {
    nome = novoNome;
    final p = await SharedPreferences.getInstance();
    await p.setString(_chNome, novoNome);
    if (novoToken != null) {
      token = novoToken;
      await p.setString(_chToken, novoToken);
    }
    notifyListeners();
  }

  Future<void> sair() async {
    token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_chToken);
    notifyListeners();
  }

  Future<void> trocarServidor(String endereco) async {
    var e = endereco.trim();
    while (e.endsWith('/')) {
      e = e.substring(0, e.length - 1);
    }
    servidor = e;
    final p = await SharedPreferences.getInstance();
    await p.setString(_chServidor, e);
    notifyListeners();
  }

  /// O token e um JWT: a segunda parte tem o "exp" (validade).
  /// So lemos a data aqui; quem confere a assinatura e o servidor.
  static bool _tokenVencido(String t) {
    try {
      final partes = t.split('.');
      if (partes.length != 3) return true;
      final dados = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))));
      final exp = (dados['exp'] as num?)?.toInt() ?? 0;
      return exp * 1000 < DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      return true;
    }
  }
}
