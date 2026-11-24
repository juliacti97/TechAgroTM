// =====================================================================
// perfil_tela.dart - Meu perfil (ver e editar; nao exclui a conta)
// Regras iguais ao site: trocar e-mail ou senha pede a senha atual;
// nova senha com confirmacao, 8+ caracteres, letra e numero.
// "Meus galpoes": lista e apaga galpoes (igual ao perfil do site).
// =====================================================================

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/estado.dart';
import '../core/formatos.dart';
import '../core/modelos.dart';
import '../core/situacoes.dart';
import '../core/validacao.dart';
import '../widgets/campos.dart';

class PerfilTela extends StatefulWidget {
  const PerfilTela({super.key});

  @override
  State<PerfilTela> createState() => _PerfilTelaState();
}

class _PerfilTelaState extends State<PerfilTela> {
  Conta? _conta;
  List<Aparelho> _galpoes = [];
  String? _erro, _ok;
  bool _salvando = false;

  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _propriedade = TextEditingController();
  final _senhaNova = TextEditingController();
  final _senhaNova2 = TextEditingController();
  final _senhaAtual = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    for (final c in [_nome, _email, _telefone, _propriedade, _senhaNova, _senhaNova2, _senhaAtual]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarGalpoes() async {
    try {
      final l = await api.aparelhos();
      if (mounted) setState(() => _galpoes = l);
    } catch (_) {}
  }

  Future<void> _apagarGalpao(Aparelho ap) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar galpão?'),
        content: Text('"${ap.nome}" e todo o histórico de leituras e alertas dele serão apagados. '
            'Isso não pode ser desfeito.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.alarme),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.desvincular(ap.numeroSerie);
      if (mounted) avisar(context, 'Galpão apagado.');
      _carregarGalpoes();
    } on ApiErro catch (e) {
      if (mounted) avisar(context, e.mensagem);
    }
  }

  Future<void> _carregar() async {
    _carregarGalpoes();
    try {
      final c = await api.minhaConta();
      if (!mounted) return;
      setState(() {
        _conta = c;
        _nome.text = c.nome;
        _email.text = c.email;
        _telefone.text = c.telefone;
        _propriedade.text = c.propriedade;
      });
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _salvar() async {
    setState(() {
      _erro = null;
      _ok = null;
    });
    final conta = _conta;
    String? problema;
    if (_nome.text.trim().isEmpty) problema = 'Preencha o nome.';
    problema ??= emailValido(_email.text) ? null : 'Informe um e-mail válido.';
    problema ??= problemaTelefone(_telefone.text);
    if (problema == null && _senhaNova.text.isNotEmpty) {
      problema = problemaSenha(_senhaNova.text, _senhaNova2.text);
    }
    final mudouEmail = conta != null && _email.text.trim().toLowerCase() != conta.email.toLowerCase();
    if (problema == null && (mudouEmail || _senhaNova.text.isNotEmpty) && _senhaAtual.text.isEmpty) {
      problema = 'Informe a senha atual para trocar o e-mail ou a senha.';
    }
    if (problema != null) {
      setState(() => _erro = problema);
      return;
    }

    setState(() => _salvando = true);
    try {
      final c = await api.salvarConta(
        nome: _nome.text,
        email: _email.text,
        telefone: _telefone.text,
        propriedade: _propriedade.text,
        senhaAtual: _senhaAtual.text,
        senhaNova: _senhaNova.text,
        confirma: _senhaNova2.text,
      );
      if (!mounted) return;
      setState(() {
        _conta = c;
        _ok = 'Dados salvos.';
        _senhaNova.clear();
        _senhaNova2.clear();
        _senhaAtual.clear();
      });
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _sair() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
        ],
      ),
    );
    if (ok == true) await sessao.sair();
  }

  @override
  Widget build(BuildContext context) {
    final c = _conta;
    final digitandoSenha = _senhaNova.text.isNotEmpty || _senhaNova2.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        actions: [IconButton(tooltip: 'Sair', icon: const Icon(Icons.logout), onPressed: _sair)],
      ),
      body: c == null && _erro == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_erro != null) CaixaErro(_erro!),
                if (_ok != null) CaixaOk(_ok!),
                TextField(
                  controller: _nome,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome', counterText: ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  maxLength: 150,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'E-mail', counterText: ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _telefone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [MascaraTelefone()],
                  decoration: const InputDecoration(labelText: 'Telefone', hintText: '(55) 99999-9999'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _propriedade,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Propriedade', counterText: ''),
                ),
                const SizedBox(height: 20),
                const Text('Trocar a senha', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                CampoSenha(
                  controller: _senhaNova,
                  rotulo: 'Nova senha',
                  ajuda: 'Deixe em branco para manter a atual.',
                  novaSenha: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                CampoSenha(
                  controller: _senhaNova2,
                  rotulo: 'Confirme a nova senha',
                  novaSenha: true,
                  onChanged: (_) => setState(() {}),
                ),
                if (digitandoSenha) ...[
                  const SizedBox(height: 8),
                  ListaRegras(senha: _senhaNova.text, confirma: _senhaNova2.text),
                ],
                const SizedBox(height: 12),
                CampoSenha(
                  controller: _senhaAtual,
                  rotulo: 'Senha atual',
                  ajuda: 'Obrigatória para trocar o e-mail ou a senha.',
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Cores.ambar,
                    foregroundColor: Cores.grafite,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _salvando ? null : _salvar,
                  child: Text(_salvando ? 'Salvando…' : 'Salvar alterações',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 24),
                if (c != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Resumo', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Conta criada em ${c.criadoEm != null ? dia(c.criadoEm!) : '—'}'),
                        Text('Tipo: ${c.tipo == 'admin' ? 'Administrador' : 'Produtor'}'),
                        const SizedBox(height: 8),
                        const Text('Para excluir a conta, fale com o administrador do TECH AGROTM.',
                            style: TextStyle(fontSize: 12, color: Cores.textoSuave)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Meus galpões', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if (_galpoes.isEmpty)
                        const Text('Nenhum galpão cadastrado.', style: TextStyle(color: Cores.textoSuave)),
                      for (final ap in _galpoes)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(ap.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(ap.numeroSerie, style: const TextStyle(fontSize: 12)),
                          trailing: TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Cores.alarme),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Apagar'),
                            onPressed: () => _apagarGalpao(ap),
                          ),
                        ),
                      const Text('Apagar remove também o histórico e os alertas do galpão.',
                          style: TextStyle(fontSize: 12, color: Cores.textoSuave)),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}
