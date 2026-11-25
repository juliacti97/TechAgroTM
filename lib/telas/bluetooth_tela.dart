// =====================================================================
// bluetooth_tela.dart - conecta no aparelho pelo Bluetooth
// 1. procura os aparelhos TECH AGROTM por perto
// 2. mostra a leitura em tempo real (direto do aparelho)
// 3. envia o Wi-Fi, o endereco do servidor e a criacao
// 4. mostra o numero de serie e cadastra o galpao na conta (se logado)
// 5. "ponte": se o aparelho esta sem internet (firmware 1.2+), busca as
//    leituras guardadas nele e manda para o site pela internet do celular.
// Funciona sem login (aberta pela tela de entrada): so nao mexe na conta.
// Depois do Wi-Fi configurado, o aparelho manda as leituras para a API,
// e elas aparecem no app e no site (mesmo banco).
// =====================================================================

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/aparelho_ble.dart';
import '../config.dart';
import '../core/api.dart';
import '../core/estado.dart';
import '../core/formatos.dart';
import '../core/modelos.dart';
import '../core/situacoes.dart';
import '../widgets/campos.dart';
import 'adicionar_galpao_tela.dart';

class BluetoothTela extends StatefulWidget {
  const BluetoothTela({super.key, this.filtroSerie, this.perfilAtual});

  /// Quando aberta pelo galpao: so o aparelho deste numero de serie.
  final String? filtroSerie;
  final String? perfilAtual;

  @override
  State<BluetoothTela> createState() => _BluetoothTelaState();
}

class _BluetoothTelaState extends State<BluetoothTela> {
  final AparelhoBle _ble = AparelhoBle();
  BluetoothAdapterState _adaptador = BluetoothAdapterState.unknown;
  List<ScanResult> _achados = [];
  bool _procurando = false;
  bool _mostrarTodos = false;      // lista tambem dispositivos que nao sao TECH AGROTM
  List<Aparelho> _minhaConta = []; // galpoes da conta (para achar o deste aparelho)
  Timer? _timerPonte;
  bool _repassando = false;
  int _repassadas = 0;             // leituras enviadas ao site pelo celular nesta conexao
  String? _statusPonte;
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
  final _servidor = TextEditingController();
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
    _carregarConta();
  }

  bool get _logado => sessao.logado;

  Future<void> _carregarConta() async {
    if (!_logado) return;
    try {
      final l = await api.aparelhos();
      if (mounted) setState(() => _minhaConta = l);
    } catch (_) {}
  }

  /// Numero de serie do aparelho conectado: o firmware 1.1 manda no
  /// Bluetooth; nos antigos, so temos o pedaco do nome ("AgroTM-XXXXXX").
  String? get _serieConectada => _ultima?.serie;
  String get _pedacoDoNome => (_nomeConectado ?? '').replaceFirst(RegExp(prefixoNomeBle, caseSensitive: false), '');

  /// O galpao da conta que e este aparelho (ou null).
  Aparelho? get _galpaoDaConta {
    final serie = _serieConectada;
    for (final ap in _minhaConta) {
      if (serie != null ? ap.numeroSerie.toUpperCase() == serie.toUpperCase()
                        : AparelhoBle.combina(ap.numeroSerie, _pedacoDoNome)) {
        return ap;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _subAdaptador?.cancel();
    _subBusca?.cancel();
    _subProcurando?.cancel();
    _subLeitura?.cancel();
    _subConexao?.cancel();
    _timerPonte?.cancel();
    AparelhoBle.pararBusca();
    _ble.fechar();
    for (final c in [_rede, _senhaRede, _servidor, _chave]) {
      c.dispose();
    }
    super.dispose();
  }

  /// O que mandar ao aparelho como "servidor", a partir do endereco do app.
  /// Firmware 1.x: endereco base com a pasta, ex. "https://x.onrender.com"
  ///   ou "http://192.168.0.10/TechAgroTM-php" (ele completa com /api/v1/...).
  /// Firmware 2.0: so o dominio (o caminho fica no config.h do firmware).
  static String servidorParaAparelho(String enderecoApi, {required bool comPasta}) {
    final uri = Uri.tryParse(enderecoApi);
    if (uri == null || uri.host.isEmpty) return '';
    final porta = uri.hasPort ? ':${uri.port}' : '';
    final origem = '${uri.scheme}://${uri.host}$porta';
    if (!comPasta) return uri.scheme == 'https' ? '${uri.host}$porta' : origem;
    // tira "/api/index.php" (ou "/api") do fim: sobra a pasta do projeto
    var caminho = uri.path.replaceFirst(RegExp(r'/api(/index\.php)?/?$'), '');
    while (caminho.endsWith('/')) {
      caminho = caminho.substring(0, caminho.length - 1);
    }
    return '$origem$caminho';
  }

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
      _servidor.text = servidorParaAparelho(sessao.servidor, comPasta: _ble.servidorComPasta);
      if (mounted) setState(() => _nomeConectado = AparelhoBle.nomeDe(r));
      _carregarConta();
      _repassadas = 0;
      _statusPonte = null;
      _timerPonte?.cancel();
      if (_ble.temHistorico) {
        _repassarHistorico();
        _timerPonte = Timer.periodic(const Duration(seconds: 20), (_) => _repassarHistorico());
      }
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não conectou: ${_textoErro(e)}');
    } finally {
      if (mounted) setState(() => _conectando = false);
    }
  }

  /// Ponte pelo celular: le as leituras guardadas no aparelho, manda para o
  /// site (POST /leituras/lote) e so entao pede para o aparelho apagar.
  /// Repete ate esvaziar. Roda a cada 20 s enquanto estiver conectado.
  Future<void> _repassarHistorico() async {
    if (_repassando || !_ble.conectado || !_ble.temHistorico) return;
    _repassando = true;
    try {
      for (var voltas = 0; voltas < 120; voltas++) {
        final h = await _ble.lerHistorico();
        if (h == null || h.total == 0 || h.leituras.isEmpty) {
          if (mounted) setState(() => _statusPonte = _repassadas > 0
              ? 'Pronto: $_repassadas leituras guardadas foram enviadas ao site pelo celular.'
              : null);
          break;
        }
        if (mounted) setState(() => _statusPonte = 'Enviando ao site as leituras guardadas… faltam ${h.total}.');
        await api.enviarLote(h.serie, h.perfil, h.leituras);
        await _ble.confirmarHistorico(h.primeiraEpoch, h.leituras.length);
        _repassadas += h.leituras.length;
        await Future<void>.delayed(const Duration(milliseconds: 400));   // o aparelho atualiza a lista
      }
    } on ApiErro catch (e) {
      if (mounted) setState(() => _statusPonte = e.status == 0
          ? 'O celular também está sem internet. As leituras continuam guardadas no aparelho.'
          : 'O site recusou as leituras: ${e.mensagem}');
    } catch (_) {
      // Bluetooth caiu no meio: tenta de novo na proxima volta
    } finally {
      _repassando = false;
    }
  }

  Future<void> _desconectar() async {
    _timerPonte?.cancel();
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
    final max = _ble.servidorComPasta ? 96 : 63;
    if (s.isEmpty || s.length > max) return avisar(context, 'Informe o servidor (até $max caracteres).');
    if (_chave.text.length > 47) return avisar(context, 'A chave pode ter até 47 caracteres.');
    _comando(() => _ble.enviarServidor(s, _chave.text.trim()), 'Servidor enviado ao aparelho.');
  }

  /// Troca a criacao no aparelho E na conta (senao o servidor desfaz a troca).
  Future<void> _enviarCriacao() async {
    final perfil = _perfil;
    if (perfil == null) return;
    await _comando(() => _ble.enviarCriacao(perfil), 'Criação enviada ao aparelho.');
    final ap = _galpaoDaConta;
    if (ap == null) return;   // sem login ou galpao ainda nao cadastrado
    try {
      await api.trocarCriacao(ap.numeroSerie, perfil);
      _carregarConta();
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
    final filtro = widget.filtroSerie;
    final achados = _achados.where((r) {
      if (_mostrarTodos) return AparelhoBle.nomeDe(r) != r.device.remoteId.str || AparelhoBle.ehTechAgro(r);
      if (!AparelhoBle.ehTechAgro(r)) return false;
      return filtro == null || AparelhoBle.combina(filtro, AparelhoBle.sufixoDe(r));
    }).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return [
      const Text(
        'Fique perto do aparelho (até uns 10 metros). Ele aparece como "AgroTM-" seguido de 6 letras/números do número de série.',
        style: TextStyle(color: Cores.textoSuave),
      ),
      if (Platform.isAndroid)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Android 11 ou mais antigo: deixe a Localização do celular ligada para a busca funcionar.',
              style: TextStyle(color: Cores.textoSuave, fontSize: 12)),
        ),
      if (filtro != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Procurando o aparelho $filtro.', style: const TextStyle(fontWeight: FontWeight.w600)),
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
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Mostrar todos os dispositivos Bluetooth'),
        subtitle: const Text('Use se o aparelho não aparecer com o nome AgroTM.'),
        value: _mostrarTodos,
        onChanged: (v) => setState(() => _mostrarTodos = v),
      ),
      if (!_procurando && achados.isEmpty)
        const Text('Nenhum aparelho encontrado ainda. Confira se ele está ligado e se o Bluetooth do celular está ativo.',
            style: TextStyle(color: Cores.textoSuave)),
      for (final r in achados)
        Card(
          child: ListTile(
            leading: Icon(AparelhoBle.ehTechAgro(r) ? Icons.sensors : Icons.bluetooth,
                color: AparelhoBle.ehTechAgro(r) ? Cores.verde : Cores.textoSuave),
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
    final existePerfil = _perfis.any((p) => p.id == _perfil);
    final galpao = _galpaoDaConta;

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
              if (l.rede != null) ...[
                const SizedBox(height: 6),
                Text(_textoRede(l), style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: l.rede == 'wifi' || l.rede == 'cabo' ? Cores.verde : Cores.alarme)),
              ],
            ],
            if (_statusPonte != null) ...[
              const SizedBox(height: 8),
              Text(_statusPonte!, style: const TextStyle(fontSize: 13, color: Cores.frio, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
      ),

      // numero de serie e conta
      _cartao('Número de série', [
        SelectableText(
          _serieConectada ?? 'Começa com ${_pedacoDoNome.isEmpty ? '?' : _pedacoDoNome}…',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        if (_serieConectada == null)
          const Text(
            'O número completo aparece na 4ª tela do visor (firmware 1.1) ou no Monitor Serial da Arduino IDE.',
            style: TextStyle(fontSize: 12, color: Cores.textoSuave),
          ),
        const SizedBox(height: 8),
        if (!_logado)
          const Text('Entre na sua conta para ligar este aparelho a um galpão.',
              style: TextStyle(color: Cores.textoSuave))
        else if (galpao != null)
          Text('Galpão "${galpao.nome}" da sua conta. As leituras aparecem no app e no site.',
              style: const TextStyle(color: Cores.verde, fontWeight: FontWeight.w600))
        else
          FilledButton.icon(
            icon: const Icon(Icons.add_home_work_outlined),
            label: const Text('Cadastrar como galpão na minha conta'),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => AdicionarGalpaoTela(serieSugerida: _serieConectada ?? _pedacoDoNome),
              ));
              _carregarConta();
            },
          ),
      ]),

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
        if (!_ble.temNuvem)
          const Text(
            'O firmware deste aparelho não deixa trocar o servidor pelo Bluetooth: o endereço está fixo no código '
            '(SERVIDOR_NUVEM). Grave o firmware 1.1 para configurar por aqui.',
            style: TextStyle(fontSize: 12, color: Cores.alarme),
          )
        else ...[
        Text(
          _ble.servidorComPasta
              ? 'O aparelho manda as leituras para este endereço + "/api/v1/leituras". '
                'Já vem preenchido com o mesmo servidor do app, para os dados irem para o mesmo banco.'
              : 'Firmware 2.0: informe só o domínio (o caminho da API fica no config.h do firmware).',
          style: const TextStyle(fontSize: 12, color: Cores.textoSuave),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _servidor,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Servidor', hintText: 'https://meusite.onrender.com'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _chave,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Chave do aparelho (DEVICE_KEY)', helperText: 'Deixe em branco se a API não usa chave.'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _enviarServidor, child: const Text('Enviar servidor ao aparelho')),
        ],
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
          child: Text(galpao != null ? 'Enviar criação (aparelho e conta)' : 'Enviar criação ao aparelho'),
        ),
      ]),
    ];
  }

  String _textoRede(LeituraBle l) {
    final g = l.guardadas ?? 0;
    final guardadas = g > 0 ? ' · $g leituras guardadas' : '';
    switch (l.rede) {
      case 'wifi':
        return 'Aparelho online pelo Wi-Fi$guardadas';
      case 'cabo':
        return 'Aparelho online pelo cabo$guardadas';
      case 'celular':
        return 'Aparelho sem internet: este celular está enviando as leituras$guardadas';
      default:
        return 'Aparelho sem internet, tentando reconectar$guardadas';
    }
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
