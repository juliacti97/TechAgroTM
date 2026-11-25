// =====================================================================
// aparelho_ble.dart - conversa com o Sentinela AgroTM S1 por Bluetooth
//
// Protocolo do firmware (TechAgroTM.ino, secao 4 BLUETOOTH):
//   LEITURA (read/notify) JSON {"serie"?,"fw"?,"t","u","sit","msg","perfil","neb","itu"?}
//   PERFIL  (write)  "corte_s1"            troca a criacao
//   REDE    (write)  "NomeDaRede|senha"    configura o Wi-Fi
//   NUVEM   (write)  "servidor|chave"      endereco da API (firmware 1.1+ e 2.0)
//   HISTORICO (read/write, firmware 1.2+)  leituras guardadas sem internet:
//     le {"serie","perfil","total","agora","leituras":[{"e","t","u","s"}]}
//     e responde "ok:<e da 1a>:<quantas>" depois de mandar ao site.
// Funciona com as duas familias de UUID (veja BleUuids em config.dart).
// =====================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../config.dart';
import '../core/formatos.dart';

/// Uma leitura recebida pelo Bluetooth (tempo real, sem passar pela nuvem).
class LeituraBle {
  final double? temperatura, umidade, itu;
  final String situacao, mensagem, perfil;
  final String? serie, firmware;
  final String? rede;      // por onde o aparelho envia: wifi, cabo, celular, nenhuma (1.2+)
  final int? guardadas;    // leituras esperando conexao (1.2+)
  final bool nebulizador;
  final DateTime em;

  LeituraBle.deJson(Map<String, dynamic> j)
      : temperatura = paraDouble(j['t']),
        umidade = paraDouble(j['u']),
        itu = paraDouble(j['itu']),
        situacao = (j['sit'] ?? '').toString(),
        mensagem = (j['msg'] ?? '').toString(),
        perfil = (j['perfil'] ?? '').toString(),
        serie = (j['serie'] ?? '').toString().isEmpty ? null : j['serie'].toString(),
        firmware = j['fw']?.toString(),
        rede = j['rede']?.toString(),
        guardadas = (j['guardadas'] as num?)?.toInt(),
        nebulizador = paraBool(j['neb']),
        em = DateTime.now();
}

/// Um pedaco do historico guardado no aparelho (ate 8 leituras).
class HistoricoBle {
  final String serie, perfil;
  final int total;
  final List<Map<String, dynamic>> leituras;   // ja no formato do POST /leituras/lote
  final int primeiraEpoch;
  HistoricoBle(this.serie, this.perfil, this.total, this.leituras, this.primeiraEpoch);
}

class AparelhoBle {
  BluetoothDevice? dispositivo;
  BluetoothCharacteristic? _leitura, _perfil, _rede, _nuvem, _historico;
  StreamSubscription<List<int>>? _subValor;

  /// 'a6e07' (firmware 1.x) ou 'a6207' (firmware 2.0); null se desconectado.
  String? familia;

  final StreamController<LeituraBle> _leituras = StreamController<LeituraBle>.broadcast();
  Stream<LeituraBle> get leituras => _leituras.stream;

  /* ---------------- UUIDs ---------------- */

  static final Map<int, Set<Guid>> _uuids = {
    for (final n in [BleUuids.servico, BleUuids.leitura, BleUuids.perfil, BleUuids.rede, BleUuids.nuvem, BleUuids.historico])
      n: {for (final f in BleUuids.familias) Guid(BleUuids.uuid(f, n))},
  };

  static bool _eh(Guid g, int n) => _uuids[n]?.contains(g) ?? false;

  /* ---------------- busca ---------------- */

  /// Procura dispositivos Bluetooth por perto. Nao filtra pelo servico:
  /// alguns celulares nao recebem o UUID no anuncio (o nome ocupa o espaco)
  /// e entao o aparelho nunca aparecia. A tela filtra pelo nome.
  static Future<void> procurar({Duration tempo = const Duration(seconds: 12)}) async {
    if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan(timeout: tempo);
  }

  static Future<void> pararBusca() => FlutterBluePlus.stopScan();

  /// E um aparelho TECH AGROTM? (pelo nome "AgroTM-..." ou pelo servico anunciado)
  static bool ehTechAgro(ScanResult r) {
    if (nomeDe(r).toUpperCase().startsWith('AGROTM')) return true;
    return r.advertisementData.serviceUuids.any((g) => _eh(g, BleUuids.servico));
  }

  /// "AgroTM-TA1A2B" -> "TA1A2B" (6 caracteres do numero de serie)
  static String sufixoDe(ScanResult r) {
    final nome = nomeDe(r);
    return nome.toUpperCase().startsWith(prefixoNomeBle.toUpperCase())
        ? nome.substring(prefixoNomeBle.length)
        : nome;
  }

  static String nomeDe(ScanResult r) {
    if (r.advertisementData.advName.isNotEmpty) return r.advertisementData.advName;
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    return r.device.remoteId.str;
  }

  /// O pedaco do nome Bluetooth combina com o numero de serie?
  /// (firmware 1.x usa o comeco do numero; o 2.0, o fim)
  static bool combina(String numeroSerie, String pedaco) {
    final s = numeroSerie.trim().toUpperCase(), p = pedaco.trim().toUpperCase();
    if (s.isEmpty || p.isEmpty) return false;
    return s == p || s.startsWith(p) || s.endsWith(p);
  }

  /* ---------------- conexao ---------------- */

  Future<void> conectar(BluetoothDevice d) async {
    await desconectar();
    // Uso educacional / sem fins lucrativos (licenca da biblioteca: veja o README)
    await d.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
    dispositivo = d;

    final servicos = await d.discoverServices();
    for (final s in servicos) {
      if (!_eh(s.uuid, BleUuids.servico)) continue;
      familia = s.uuid.str128.toLowerCase().split('-').last.substring(0, 5);
      for (final c in s.characteristics) {
        if (_eh(c.uuid, BleUuids.leitura)) _leitura = c;
        if (_eh(c.uuid, BleUuids.perfil)) _perfil = c;
        if (_eh(c.uuid, BleUuids.rede)) _rede = c;
        if (_eh(c.uuid, BleUuids.nuvem)) _nuvem = c;
        if (_eh(c.uuid, BleUuids.historico)) _historico = c;
      }
    }
    if (_leitura == null || _rede == null) {
      await desconectar();
      throw Exception('Este dispositivo não é um aparelho TECH AGROTM (serviço Bluetooth não encontrado).');
    }

    _subValor = _leitura!.onValueReceived.listen(_receber);
    d.cancelWhenDisconnected(_subValor!);
    await _leitura!.setNotifyValue(true);
    try {
      _receber(await _leitura!.read());   // primeira leitura na hora
    } catch (_) {
      // ainda sem leitura no aparelho: chega pela notificacao
    }
  }

  Stream<BluetoothConnectionState>? get estadoConexao => dispositivo?.connectionState;

  bool get conectado => dispositivo?.isConnected ?? false;

  /// O firmware guarda leituras para o celular buscar? (1.2+)
  bool get temHistorico => _historico != null;

  /// Le o proximo pedaco do historico. "atras_s" e calculado aqui com o
  /// relogio do aparelho ("agora" - "e"), mais o tempo ate o envio.
  Future<HistoricoBle?> lerHistorico() async {
    final c = _historico;
    if (c == null || !conectado) return null;
    final j = jsonDecode(utf8.decode(await c.read()));
    if (j is! Map<String, dynamic>) return null;
    final agora = (j['agora'] as num?)?.toInt() ?? 0;
    final lista = <Map<String, dynamic>>[];
    var primeira = -1;
    for (final l in (j['leituras'] as List? ?? const [])) {
      if (l is! Map) continue;
      final e = (l['e'] as num?)?.toInt() ?? agora;
      if (primeira < 0) primeira = e;
      lista.add({
        'temperatura': l['t'],
        'umidade': l['u'],
        'situacao': (l['s'] ?? 'conforto').toString(),
        'atras_s': (agora - e).clamp(0, 7 * 24 * 3600),
      });
    }
    return HistoricoBle((j['serie'] ?? '').toString(), (j['perfil'] ?? '').toString(),
        (j['total'] as num?)?.toInt() ?? 0, lista, primeira);
  }

  /// Avisa o aparelho que estas leituras ja estao no site (ele apaga).
  Future<void> confirmarHistorico(int primeiraEpoch, int quantas) =>
      _escrever(_historico, 'ok:$primeiraEpoch:$quantas');

  /// O firmware aceita trocar o servidor pelo Bluetooth? (1.1+ e 2.0)
  bool get temNuvem => _nuvem != null;

  /// Firmware 1.x: o servidor e o endereco base (com a pasta, se houver).
  /// Firmware 2.0: so o dominio (o caminho fica no config.h).
  bool get servidorComPasta => familia == 'a6e07';

  Future<void> desconectar() async {
    await _subValor?.cancel();
    _subValor = null;
    final d = dispositivo;
    dispositivo = null;
    familia = null;
    _leitura = _perfil = _rede = _nuvem = _historico = null;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
  }

  void _receber(List<int> bytes) {
    if (bytes.isEmpty) return;
    try {
      final j = jsonDecode(utf8.decode(bytes));
      if (j is Map<String, dynamic>) _leituras.add(LeituraBle.deJson(j));
    } catch (_) {
      // pacote incompleto: ignora, o proximo vem em segundos
    }
  }

  /* ---------------- comandos ---------------- */

  Future<void> _escrever(BluetoothCharacteristic? c, String texto) async {
    if (c == null || !conectado) throw Exception('Aparelho desconectado. Conecte de novo.');
    await c.write(utf8.encode(texto));
  }

  /// Wi-Fi do galpao. O nome da rede nao pode ter "|" (separador do protocolo).
  Future<void> enviarWifi(String rede, String senha) {
    if (rede.isEmpty || rede.contains('|')) {
      throw Exception('Nome da rede inválido.');
    }
    return _escrever(_rede, '$rede|$senha');
  }

  /// Endereco da API e a chave (DEVICE_KEY), se houver.
  Future<void> enviarServidor(String servidor, String chave) {
    if (_nuvem == null) {
      throw Exception('Este firmware não aceita trocar o servidor pelo Bluetooth. Grave o firmware 1.1.');
    }
    return _escrever(_nuvem, chave.isEmpty ? servidor : '$servidor|$chave');
  }

  /// Troca a criacao direto no aparelho (o servidor tambem deve ser avisado).
  Future<void> enviarCriacao(String perfilId) => _escrever(_perfil, perfilId);

  void fechar() {
    desconectar();
    _leituras.close();
  }
}
