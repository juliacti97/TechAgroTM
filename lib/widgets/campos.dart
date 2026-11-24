// =====================================================================
// campos.dart - pecas de formulario reaproveitadas pelas telas
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/situacoes.dart';
import '../core/validacao.dart';

/// Campo de senha com o botao Mostrar / Ocultar.
class CampoSenha extends StatefulWidget {
  const CampoSenha({
    super.key,
    required this.controller,
    required this.rotulo,
    this.ajuda,
    this.novaSenha = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String rotulo;
  final String? ajuda;
  final bool novaSenha;
  final ValueChanged<String>? onChanged;

  @override
  State<CampoSenha> createState() => _CampoSenhaState();
}

class _CampoSenhaState extends State<CampoSenha> {
  bool _escondida = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _escondida,
      maxLength: 72,
      autofillHints: [widget.novaSenha ? AutofillHints.newPassword : AutofillHints.password],
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.rotulo,
        helperText: widget.ajuda,
        counterText: '',
        suffixIcon: TextButton(
          onPressed: () => setState(() => _escondida = !_escondida),
          child: Text(_escondida ? 'Mostrar' : 'Ocultar'),
        ),
      ),
    );
  }
}

/// Regras da senha, que ficam verdes conforme a pessoa digita.
class ListaRegras extends StatelessWidget {
  const ListaRegras({super.key, required this.senha, required this.confirma});
  final String senha, confirma;

  @override
  Widget build(BuildContext context) {
    final regras = regrasSenha(senha, confirma);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in regras)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              Icon(r.ok ? Icons.check : Icons.radio_button_unchecked,
                  size: 16, color: r.ok ? Cores.verde : Cores.textoSuave),
              const SizedBox(width: 6),
              Text(r.texto,
                  style: TextStyle(fontSize: 13, color: r.ok ? Cores.verde : Cores.textoSuave)),
            ]),
          ),
      ],
    );
  }
}

/// Formata o telefone enquanto digita: (55) 99999-9999
class MascaraTelefone extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final texto = mascararTelefone(novo.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Caixa vermelha de erro (igual a do site)
class CaixaErro extends StatelessWidget {
  const CaixaErro(this.mensagem, {super.key});
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFF5E4E0),
        border: Border(left: BorderSide(color: Cores.alarme, width: 3)),
      ),
      child: Text(mensagem,
          style: const TextStyle(color: Cores.alarme, fontWeight: FontWeight.w600)),
    );
  }
}

/// Caixa verde de sucesso
class CaixaOk extends StatelessWidget {
  const CaixaOk(this.mensagem, {super.key});
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFE2EFE5),
        border: Border(left: BorderSide(color: Cores.verde, width: 3)),
      ),
      child: Text(mensagem,
          style: const TextStyle(color: Color(0xFF2D5A3A), fontWeight: FontWeight.w600)),
    );
  }
}

/// Lista de opcoes (criacao, UF, cidade...) com rotulo, no estilo dos campos.
/// Usa DropdownButton simples, que funciona igual em todas as versoes do Flutter.
class CampoEscolha<T> extends StatelessWidget {
  const CampoEscolha({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.itens,
    required this.aoEscolher,
    this.dica,
  });

  final String rotulo;
  final T? valor;
  final List<DropdownMenuItem<T>> itens;
  final ValueChanged<T?>? aoEscolher;
  final String? dica;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: rotulo,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valor,
          items: itens,
          onChanged: aoEscolher,
          isExpanded: true,
          hint: dica == null ? null : Text(dica!),
        ),
      ),
    );
  }
}

/// Mostra uma mensagem rapida no rodape.
void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}
