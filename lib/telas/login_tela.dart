// =====================================================================
// login_tela.dart - Entrar / Primeiro acesso
// Mesmos campos e regras do site: nome, e-mail, telefone e propriedade
// (opcionais), senha com confirmacao (8+ caracteres, letra e numero).
// =====================================================================

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/estado.dart';
import '../core/situacoes.dart';
import '../core/validacao.dart';
import '../widgets/campos.dart';

class LoginTela extends StatefulWidget {
  const LoginTela({super.key});

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  bool _criar = false;
  bool _enviando = false;
  String? _erro;

  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _propriedade = TextEditingController();
  final _senha = TextEditingController();
  final _senha2 = TextEditingController();

  @override
  void dispose() {
    for (final c in [_nome, _email, _telefone, _propriedade, _senha, _senha2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _erro = null);
    final email = _email.text.trim();

    // as mesmas conferencias do site, antes de chamar a API
    String? problema;
    if (_criar && _nome.text.trim().isEmpty) problema = 'Informe o seu nome.';
    problema ??= emailValido(email) ? null : 'Informe um e-mail válido.';
    if (problema == null && _senha.text.isEmpty) problema = 'Informe a senha.';
    if (problema == null && _criar) {
      problema = problemaTelefone(_telefone.text) ?? problemaSenha(_senha.text, _senha2.text);
    }
    if (problema != null) {
      setState(() => _erro = problema);
      return;
    }

    setState(() => _enviando = true);
    try {
      if (_criar) {
        await api.cadastrar(
          nome: _nome.text,
          email: email,
          senha: _senha.text,
          confirma: _senha2.text,
          telefone: _telefone.text,
          propriedade: _propriedade.text,
        );
      } else {
        await api.entrar(email, _senha.text);
      }
      // a sessao avisa o app, que troca para a tela inicial sozinho
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _configurarServidor() async {
    final campo = TextEditingController(text: sessao.servidor);
    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor da API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Endereço da API do TECH AGROTM. Exemplos:\n'
              '• Emulador + XAMPP: http://10.0.2.2/TechAgroTM-php/api/index.php\n'
              '• Celular na mesma rede: http://192.168.0.10/TechAgroTM-php/api/index.php\n'
              '• Internet: https://seu-site.onrender.com/api/index.php',
              style: TextStyle(fontSize: 12, color: Cores.textoSuave),
            ),
            const SizedBox(height: 12),
            TextField(controller: campo, keyboardType: TextInputType.url, autocorrect: false),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, campo.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (novo != null && novo.trim().isNotEmpty) {
      await sessao.trocarServidor(novo);
      if (!mounted) return;
      setState(() {});
      avisar(context, 'Servidor salvo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TECH AGROTM'),
        actions: [
          IconButton(
            tooltip: 'Servidor da API',
            icon: const Icon(Icons.dns_outlined),
            onPressed: _configurarServidor,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_criar ? 'Primeiro acesso' : 'Acompanhe seu galpão',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              _criar
                  ? 'Crie sua conta grátis. Depois é só adicionar o galpão com o número de série do aparelho.'
                  : 'Entre para ver as leituras, o gráfico e a previsão do tempo da sua propriedade.',
              style: const TextStyle(color: Cores.textoSuave),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Entrar')),
                ButtonSegment(value: true, label: Text('Primeiro acesso')),
              ],
              selected: {_criar},
              onSelectionChanged: (s) => setState(() {
                _criar = s.first;
                _erro = null;
              }),
            ),
            const SizedBox(height: 16),
            if (_erro != null) CaixaErro(_erro!),
            AutofillGroup(
              child: Column(children: [
                if (_criar) ...[
                  TextField(
                    controller: _nome,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 100,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(labelText: 'Nome', counterText: ''),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  maxLength: 150,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'E-mail', counterText: ''),
                ),
                const SizedBox(height: 12),
                if (_criar) ...[
                  TextField(
                    controller: _telefone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [MascaraTelefone()],
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                        labelText: 'Telefone (opcional)', hintText: '(55) 99999-9999'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _propriedade,
                    maxLength: 100,
                    decoration: const InputDecoration(
                        labelText: 'Propriedade (opcional)', hintText: 'Granja Boa Vista', counterText: ''),
                  ),
                  const SizedBox(height: 12),
                ],
                CampoSenha(
                  controller: _senha,
                  rotulo: 'Senha',
                  novaSenha: _criar,
                  onChanged: (_) => setState(() {}),
                ),
                if (_criar) ...[
                  const SizedBox(height: 12),
                  CampoSenha(
                    controller: _senha2,
                    rotulo: 'Confirme a senha',
                    novaSenha: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  ListaRegras(senha: _senha.text, confirma: _senha2.text),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Cores.ambar,
                foregroundColor: Cores.grafite,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_criar ? 'Criar conta' : 'Entrar',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Text('Servidor: ${sessao.servidor}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Cores.textoSuave)),
          ],
        ),
      ),
    );
  }
}
