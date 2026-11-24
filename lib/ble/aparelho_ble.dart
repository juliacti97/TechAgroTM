// =====================================================================
// aparelho_ble.dart - conversa com o Sentinela AgroTM S1 por Bluetooth
//
// Protocolo do firmware (TechAgroTM.ino, secao 4 BLUETOOTH):
//   LEITURA (notify) JSON {"t","u","sit","msg","perfil","neb","itu"?}
//   PERFIL  (write)  "corte_s1"            troca a criacao
//   REDE    (write)  "NomeDaRede|senha"    configura o Wi-Fi
//   NUVEM   (write)  "servidor|chave"      endereco da API e DEVICE_KEY
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
  final bool nebulizador;
  final DateTime em;

  LeituraBle.deJson(Map<String, dynamic> j)
      : temperatura = paraDouble(j['t']),
        umidade = paraDouble(j['u']),
        itu = paraDouble(j['itu']),
        situacao = (j['sit'] ?? '').toString(),
        mensagem = (j['msg'] ?? '').toString(),
        perfil = (j['perfil'] ?? '').toString(),
        nebulizador = paraBool(j['neb']),
        em = DateTime.now();
}

class AparelhoBle {
  static final Guid _servico = Guid(BleUuids.servico);
  static final Guid _uLeitura = Guid(BleUuids.leitura);
  static final Guid _uPerfil = Guid(BleUuids.perfil);
  static final Guid _uRede = Guid(BleUuids.rede);
  static final Guid _uNuvem = Guid(BleUuids.nuvem);

  BluetoothDevice? dispositivo;
  BluetoothCharacteristic? _leitura, _perfil, _rede, _nuvem;
  StreamSubscription<List<int>>? _subValor;

  final StreamController<LeituraBle> _leituras = StreamController<LeituraBle>.broadcast();
  Stream<LeituraBle> get leituras => _leituras.stream;

  /* ---------------- busca ---------------- */

  /// Procura aparelhos TECH AGROTM por perto (pelo servico BLE deles).
  static Future<void> procurar({Duration tempo = const Duration(seconds: 10)}) async {
    if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan(withServices: [_servico], timeout: tempo);
  }

  static Future<void> pararBusca() => FlutterBluePlus.stopScan();

  /// "AgroTM-A1B2C3" -> "A1B2C3" (fim do numero de serie)
  static String sufixoDe(ScanResult r) {
    final nome = nomeDe(r);
    return nome.startsWith(prefixoNomeBle) ? nome.substring(prefixoNomeBle.length) : nome;
  }

  static String nomeDe(ScanResult r) {
    if (r.advertisementData.advName.isNotEmpty) return r.advertisementData.advName;
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    return r.device.remoteId.str;
  }

  /* ---------------- conexao ---------------- */

  Future<void> conectar(BluetoothDevice d) async {
    await desconectar();
    // Uso educacional / sem fins lucrativos (licenca da biblioteca: veja o README)
    await d.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
    dispositivo = d;

    final servicos = await d.discoverServices();
    for (final s in servicos) {
      if (s.uuid != _servico) continue;
      for (final c in s.characteristics) {
        if (c.uuid == _uLeitura) _leitura = c;
        if (c.uuid == _uPerfil) _perfil = c;
        if (c.uuid == _uRede) _rede = c;
        if (c.uuid == _uNuvem) _nuvem = c;
      }
    }
    if (_leitura == null || _rede == null) {
      await desconectar();
      throw Exception('Este aparelho não parece ser um TECH AGROTM (serviço Bluetooth não encontrado).');
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

  Future<void> desconectar() async {
    await _subValor?.cancel();
    _subValor = null;
    final d = dispositivo;
    dispositivo = null;
    _leitura = _perfil = _rede = _nuvem = null;
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

  /// Endereco da API (so o dominio ou http://IP, sem o caminho) e a chave.
  Future<void> enviarServidor(String servidor, String chave) =>
      _escrever(_nuvem, chave.isEmpty ? servidor : '$servidor|$chave');

  /// Troca a criacao direto no aparelho (o servidor tambem deve ser avisado).
  Future<void> enviarCriacao(String perfilId) => _escrever(_perfil, perfilId);

  void fechar() {
    desconectar();
    _leituras.close();
  }
}
