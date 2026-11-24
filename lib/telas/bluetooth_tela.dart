// =====================================================================
// bluetooth_tela.dart - conecta no aparelho pelo Bluetooth
// 1. procura os aparelhos TECH AGROTM por perto
// 2. mostra a leitura em tempo real (direto do aparelho)
// 3. envia o Wi-Fi, o endereco do servidor e a criacao
// Depois do Wi-Fi configurado, o aparelho manda as leituras para a API,
// e elas aparecem no app e no site (mesmo banco).
// =====================================================================

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/aparelho_ble.dart';
import '../core/api.dart';
import '../core/estado.dart';
import '../core/formatos.dart';
import '../core/modelos.dart';
import '../core/situacoes.dart';
import '../widgets/campos.dart';

class BluetoothTela extends StatefulWidget {
  const BluetoothTela({super.key, this.filtroSufixo, this.perfilAtual});

  /// Quando aberta pelo galpao: so o aparelho que termina com este codigo.
  final String? filtroSufixo;
  final String? perfilAtual;

  @override
  State<BluetoothTela> createState() => _BluetoothTelaState();
}

class _BluetoothTelaState extends State<BluetoothTela> {
  final AparelhoBle _ble = AparelhoBle();
  BluetoothAdapterState _adaptador = BluetoothAdapterState.unknown;
  List<ScanResult> _achados = [];
  bool _procurando = false;
  bool _conectando = false;
  String? _nomeConectado;
  LeituraBle? _ultima;
  String? _erro;

  StreamSubscription<BluetoothAdapterState>? _subAdaptador;
  StreamSubscription<List<ScanResult>>? _subBusca;
  StreamSubscription<bool>? _subProcurando;
  StreamSubscription<LeituraBle>? _subLeitura;
  StreamSubscription<BluetoothConnectionState>? _subConexao;

  final _rede = TextEditingController();
  final _senhaRede = TextEditingController();
  late final TextEditingController _servidor = TextEditingController(text: _origemDoServidor());
  final _chave = TextEditingController();
  String? _perfil;
  List<Perfil> _perfis = [];

  @override
  void initState() {
    super.initState();
    _perfil = widget.perfilAtual;
    carregarPerfis().then((l) {
      if (mounted) setState(() => _perfis = l);
    }).catchError((Object _) {});

    _subAdaptador = FlutterBluePlus.adapterState.listen((s) {
      if (!mounted) return;
      setState(() => _adaptador = s);
      if (s == BluetoothAdapterState.on && _achados.isEmpty && !_ble.conectado) _procurar();
    });
    _subBusca = FlutterBluePlus.onScanResults.listen((lista) {
      if (mounted) setState(() => _achados = lista);
    });
    _subProcurando = FlutterBluePlus.isScanning.listen((v) {
      if (mounted) setState(() => _procurando = v);
    });
    _subLeitura = _ble.leituras.listen((l) {
      if (mounted) setState(() => _ultima = l);
    });
  }

  @override
  void dispose() {
    _subAdaptador?.cancel();
    _subBusca?.cancel();
    _subProcurando?.cancel();
    _subLeitura?.cancel();
    _subConexao?.cancel();
    AparelhoBle.pararBusca();
    _ble.fechar();
    for (final c in [_rede, _senhaRede, _servidor, _chave]) {
      c.dispose();
    }
    super.dispose();
  }

  /// O firmware guarda so o "dominio" (ou http://IP); o caminho da API
  /// (CAMINHO_API) fica gravado no proprio firmware.
  static String _origemDoServidor() {
    final uri = Uri.tryParse(sessao.servidor);
    if (uri == null || uri.host.isEmpty) return '';
    final porta = uri.hasPort ? ':${uri.port}' : '';
    return uri.scheme == 'https' ? '${uri.host}$porta' : 'http://${uri.host}$porta';
  }

  static String _caminhoDoServidor() => Uri.tryParse(sessao.servidor)?.path ?? '';

  Future<void> _procurar() async {
    setState(() {
      _erro = null;
      _achados = [];
    });
    try {
      await AparelhoBle.procurar();
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não foi possível procurar: $e');
    }
  }

  Future<void> _conectar(ScanResult r) async {
    setState(() {
      _conectando = true;
      _erro = null;
    });
    try {
      await AparelhoBle.pararBusca();
      await _ble.conectar(r.device);
      _subConexao?.cancel();
      _subConexao = _ble.estadoConexao?.listen((s) {
        if (s == BluetoothConnectionState.disconnected && mounted) {
          setState(() {
            _nomeConectado = null;
            _ultima = null;
          });
        }
      });
      if (mounted) setState(() => _nomeConectado = AparelhoBle.nomeDe(r));
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não conectou: ${_textoErro(e)}');
    } finally {
      if (mounted) setState(() => _conectando = false);
    }
  }

  Future<void> _desconectar() async {
    await _ble.desconectar();
    if (mounted) setState(() {
      _nomeConectado = null;
      _ultima = null;
    });
  }

  String _textoErro(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _comando(Future<void> Function() fazer, String ok) async {
    try {
      await fazer();
      if (mounted) avisar(context, ok);
    } catch (e) {
      if (mounted) avisar(context, _textoErro(e));
    }
  }

  void _enviarWifi() {
    final rede = _rede.text.trim();
    if (rede.isEmpty) return avisar(context, 'Informe o nome da rede Wi-Fi.');
    if (rede.contains('|')) return avisar(context, 'O nome da rede não pode ter o caractere "|".');
    _comando(() => _ble.enviarWifi(rede, _senhaRede.text),
        'Wi-Fi enviado. O aparelho conecta em alguns segundos (veja o visor).');
  }

  void _enviarServidor() {
    final s = _servidor.text.trim();
    if (s.isEmpty || s.length > 63) return avisar(context, 'Informe o servidor (até 63 caracteres).');
    if (_chave.text.length > 47) return avisar(context, 'A chave pode ter até 47 caracteres.');
    _comando(() => _ble.enviarServidor(s, _chave.text.trim()), 'Servidor enviado ao aparelho.');
  }

  /// Troca a criacao no aparelho E na conta (senao o servidor desfaz a troca).
  Future<void> _enviarCriacao() async {
    final perfil = _perfil;
    if (perfil == null) return;
    await _comando(() => _ble.enviarCriacao(perfil), 'Criação enviada ao aparelho.');
    final sufixo = (_nomeConectado ?? '').replaceFirst('AgroTM-', '');
    try {
      for (final ap in await api.aparelhos()) {
        if (sufixo.isNotEmpty && ap.numeroSerie.toUpperCase().endsWith(sufixo.toUpperCase())) {
          await api.trocarCriacao(ap.numeroSerie, perfil);
        }
      }
    } on ApiErro catch (e) {
      if (mounted) avisar(context, 'Aparelho trocou, mas o servidor não: ${e.mensagem}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aparelho (Bluetooth)'),
        actions: [
          if (_nomeConectado != null)
            TextButton(
              onPressed: _desconectar,
              child: const Text('Desconectar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erro != null) CaixaErro(_erro!),
          if (_adaptador != BluetoothAdapterState.on && _adaptador != BluetoothAdapterState.unknown)
            _bluetoothDesligado()
          else if (_nomeConectado == null)
            ..._lista()
          else
            ..._conectado(),
        ],
      ),
    );
  }

  Widget _bluetoothDesligado() {
    final semPermissao = _adaptador == BluetoothAdapterState.unauthorized;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(semPermissao ? 'O app não tem permissão de Bluetooth' : 'O Bluetooth está desligado',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            semPermissao
                ? 'Libere o Bluetooth (e "Dispositivos próximos") para o TECH AGROTM nas configurações do celular.'
                : 'Ligue o Bluetooth para encontrar o aparelho do galpão.',
            style: const TextStyle(color: Cores.textoSuave),
          ),
          if (!semPermissao && Platform.isAndroid) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: () => FlutterBluePlus.turnOn(), child: const Text('Ligar o Bluetooth')),
          ],
        ]),
      ),
    );
  }

  List<Widget> _lista() {
    final filtro = widget.filtroSufixo?.toUpperCase();
    final achados = filtro == null
        ? _achados
        : _achados.where((r) => AparelhoBle.sufixoDe(r).toUpperCase() == filtro).toList();
    return [
      const Text(
        'Fique perto do aparelho (até uns 10 metros). Ele aparece como "AgroTM-" seguido do final do número de série.',
        style: TextStyle(color: Cores.textoSuave),
      ),
      if (filtro != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Procurando o aparelho que termina em $filtro.',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _procurando ? null : _procurar,
        icon: _procurando
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.bluetooth_searching),
        label: Text(_procurando ? 'Procurando…' : 'Procurar aparelhos'),
      ),
      const SizedBox(height: 12),
      if (!_procurando && achados.isEmpty)
        const Text('Nenhum aparelho encontrado ainda. Confira se ele está ligado.',
            style: TextStyle(color: Cores.textoSuave)),
      for (final r in achados)
        Card(
          child: ListTile(
            leading: const Icon(Icons.sensors, color: Cores.verde),
            title: Text(AparelhoBle.nomeDe(r), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Sinal ${r.rssi} dBm'),
            trailing: _conectando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Conectar'),
            onTap: _conectando ? null : () => _conectar(r),
          ),
        ),
    ];
  }

  List<Widget> _conectado() {
    final l = _ultima;
    final sit = l == null ? null : situacaoDe(l.situacao);
    final perfil = l == null ? null : perfilPorId(l.perfil);
    final caminho = _caminhoDoServidor();
    final existePerfil = _perfis.any((p) => p.id == _perfil);

    return [
      // leitura ao vivo
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.bluetooth_connected, color: Cores.frio),
              const SizedBox(width: 6),
              Expanded(child: Text(_nomeConectado!, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (l != null) Text(hora(l.em), style: const TextStyle(color: Cores.textoSuave, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            if (l == null)
              const Text('Aguardando a leitura do aparelho…', style: TextStyle(color: Cores.textoSuave))
            else ...[
              Text('${numero(l.temperatura)} °C · ${numero(l.umidade, 0)} %${l.itu != null ? ' · ITU ${numero(l.itu, 0)}' : ''}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text(sit!.texto, style: TextStyle(color: corNivel(sit.nivel), fontWeight: FontWeight.w700)),
              if (l.mensagem.isNotEmpty) Text(l.mensagem, style: const TextStyle(color: Cores.textoSuave)),
              const SizedBox(height: 4),
              Text('Criação no aparelho: ${perfil?.nome ?? l.perfil}${l.nebulizador ? ' · nebulizador ligado' : ''}',
                  style: const TextStyle(fontSize: 12, color: Cores.textoSuave)),
            ],
          ]),
        ),
      ),

      // Wi-Fi
      _cartao('Wi-Fi do galpão', [
        TextField(controller: _rede, decoration: const InputDecoration(labelText: 'Nome da rede (SSID)')),
        const SizedBox(height: 10),
        CampoSenha(controller: _senhaRede, rotulo: 'Senha do Wi-Fi'),
        const SizedBox(height: 10),
        FilledButton(onPressed: _enviarWifi, child: const Text('Enviar Wi-Fi ao aparelho')),
      ]),

      // servidor
      _cartao('Servidor da API', [
        Text(
          'O aparelho manda as leituras para este endereço. Ele usa o caminho gravado no firmware '
          '(CAMINHO_API); o app usa "$caminho". Os dois precisam apontar para a mesma API.',
          style: const TextStyle(fontSize: 12, color: Cores.textoSuave),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _servidor,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Servidor', hintText: 'http://192.168.0.10 ou meusite.com.br'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _chave,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Chave do aparelho (DEVICE_KEY)', helperText: 'Deixe em branco se a API não usa chave.'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _enviarServidor, child: const Text('Enviar servidor ao aparelho')),
      ]),

      // criacao
      _cartao('Criação monitorada', [
        CampoEscolha<String>(
          rotulo: 'Criação',
          valor: existePerfil ? _perfil : null,
          itens: [
            for (final p in _perfis)
              DropdownMenuItem(
                value: p.id,
                child: Text('${Perfil.nomesGrupos[p.grupo] ?? p.grupo} · ${p.nome}', overflow: TextOverflow.ellipsis),
              ),
          ],
          aoEscolher: (v) => setState(() => _perfil = v),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _perfil == null ? null : _enviarCriacao,
          child: const Text('Enviar criação (aparelho e conta)'),
        ),
      ]),
    ];
  }

  Widget _cartao(String titulo, List<Widget> filhos) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            ...filhos,
          ]),
        ),
      );
}
