// =====================================================================
// config_aparelhos.dart - guarda no celular o que foi configurado em cada
// aparelho pela aba Aparelho (Wi-Fi, senha, servidor, chave e criacao),
// para nao precisar digitar tudo de novo na proxima conexao.
// Fica so neste celular (SharedPreferences), por numero de serie (ou pelo
// nome Bluetooth, nos firmwares que nao mandam o numero).
// =====================================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ConfigAparelho {
  String rede, senha, servidor, chave;
  String? perfil;
  DateTime? enviadoEm;

  ConfigAparelho({this.rede = '', this.senha = '', this.servidor = '', this.chave = '', this.perfil, this.enviadoEm});

  Map<String, dynamic> paraJson() => {
        'rede': rede,
        'senha': senha,
        'servidor': servidor,
        'chave': chave,
        'perfil': perfil,
        'enviadoEm': enviadoEm?.toIso8601String(),
      };

  factory ConfigAparelho.deJson(Map<String, dynamic> j) => ConfigAparelho(
        rede: (j['rede'] ?? '').toString(),
        senha: (j['senha'] ?? '').toString(),
        servidor: (j['servidor'] ?? '').toString(),
        chave: (j['chave'] ?? '').toString(),
        perfil: j['perfil']?.toString(),
        enviadoEm: DateTime.tryParse((j['enviadoEm'] ?? '').toString()),
      );
}

class ConfigAparelhos {
  static const _prefixo = 'agrotm_aparelho_';
  static const _ultimoWifi = 'agrotm_ultimo_wifi';   // a mesma rede costuma servir para varios galpoes

  /// Configuracao guardada deste aparelho; sem nada guardado, devolve o
  /// ultimo Wi-Fi usado em qualquer aparelho (ja vem preenchido).
  static Future<ConfigAparelho> ler(String chave) async {
    final p = await SharedPreferences.getInstance();
    final texto = p.getString(_prefixo + chave.toUpperCase());
    if (texto != null) {
      try {
        return ConfigAparelho.deJson(jsonDecode(texto) as Map<String, dynamic>);
      } catch (_) {}
    }
    final ultimo = p.getString(_ultimoWifi);
    if (ultimo != null) {
      try {
        final j = jsonDecode(ultimo) as Map<String, dynamic>;
        return ConfigAparelho(rede: (j['rede'] ?? '').toString(), senha: (j['senha'] ?? '').toString());
      } catch (_) {}
    }
    return ConfigAparelho();
  }

  static Future<void> gravar(String chave, ConfigAparelho c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefixo + chave.toUpperCase(), jsonEncode(c.paraJson()));
    if (c.rede.isNotEmpty) {
      await p.setString(_ultimoWifi, jsonEncode({'rede': c.rede, 'senha': c.senha}));
    }
  }
}
