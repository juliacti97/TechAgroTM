// =====================================================================
// adicionar_galpao_tela.dart - vincula um aparelho a conta
// Mesmos campos do painel: numero de serie, nome, criacao, UF e cidade.
// Regra do servidor: cada numero de serie fica em UMA conta so.
// =====================================================================

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/estado.dart';
import '../core/modelos.dart';
import '../core/situacoes.dart';
import '../widgets/campos.dart';
import 'seletor_cidade.dart';

class AdicionarGalpaoTela extends StatefulWidget {
  const AdicionarGalpaoTela({super.key, this.serieSugerida});

  /// Quando vem da aba Aparelho (Bluetooth), ja sugere o fim do numero.
  final String? serieSugerida;

  @override
  State<AdicionarGalpaoTela> createState() => _AdicionarGalpaoTelaState();
}

class _AdicionarGalpaoTelaState extends State<AdicionarGalpaoTela> {
  late final TextEditingController _serie = TextEditingController(text: widget.serieSugerida ?? '');
  final _apelido = TextEditingController();
  List<Perfil> _perfis = [];
  String? _perfil;
  int? _cidade;
  bool _enviando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    carregarPerfis().then((lista) {
      if (mounted) setState(() {
        _perfis = lista;
        _perfil ??= lista.isNotEmpty ? lista.first.id : null;
      });
    }).catchError((Object e) {
      if (mounted) setState(() => _erro = e.toString());
    });
  }

  @override
  void dispose() {
    _serie.dispose();
    _apelido.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final serie = _serie.text.trim();
    if (serie.isEmpty) {
      setState(() => _erro = 'Informe o número de série (está na etiqueta e na 4ª tela do visor).');
      return;
    }
    if (_perfil == null) {
      setState(() => _erro = 'Escolha a criação.');
      return;
    }
    setState(() {
      _erro = null;
      _enviando = true;
    });
    try {
      final aviso = await api.adicionarAparelho(
        numeroSerie: serie,
        apelido: _apelido.text,
        perfil: _perfil!,
        municipio: _cidade,
      );
      if (!mounted) return;
      if (aviso != null) avisar(context, 'Galpão adicionado. Aviso: $aviso');
      Navigator.of(context).pop(true);
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar galpão')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_erro != null) CaixaErro(_erro!),
          TextField(
            controller: _serie,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Número de série',
              helperText: 'Está na etiqueta do aparelho (começa com TA).',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _apelido,
            maxLength: 30,
            decoration: const InputDecoration(labelText: 'Nome do galpão', hintText: 'Ex.: Aviário 1'),
          ),
          const SizedBox(height: 6),
          CampoEscolha<String>(
            rotulo: 'Criação',
            valor: _perfil,
            itens: [
              for (final p in _perfis)
                DropdownMenuItem(
                  value: p.id,
                  child: Text('${Perfil.nomesGrupos[p.grupo] ?? p.grupo} · ${p.nome}', overflow: TextOverflow.ellipsis),
                ),
            ],
            aoEscolher: (v) => setState(() => _perfil = v),
          ),
          const SizedBox(height: 14),
          const Text('Cidade do galpão (para a previsão do tempo)',
              style: TextStyle(fontWeight: FontWeight.w600, color: Cores.textoSuave)),
          const SizedBox(height: 8),
          SeletorCidade(aoEscolher: (id) => _cidade = id),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Cores.ambar,
              foregroundColor: Cores.grafite,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _enviando ? null : _salvar,
            child: Text(_enviando ? 'Adicionando…' : 'Adicionar',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
