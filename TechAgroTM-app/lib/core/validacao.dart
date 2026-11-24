// =====================================================================
// validacao.dart - regras de senha e telefone
// As MESMAS do servidor (inc/validacao.php) e do site (conta.js).
// O app confere antes de enviar; quem decide no fim e a API.
// =====================================================================

class RegraSenha {
  final bool ok;
  final String texto;
  const RegraSenha(this.ok, this.texto);
}

/// Lista de regras para mostrar na tela (ficam verdes quando ok).
List<RegraSenha> regrasSenha(String senha, String confirma) => [
      RegraSenha(senha.length >= 8, 'Pelo menos 8 caracteres'),
      RegraSenha(RegExp(r'\p{L}', unicode: true).hasMatch(senha), 'Pelo menos uma letra'),
      RegraSenha(RegExp(r'\d').hasMatch(senha), 'Pelo menos um número'),
      RegraSenha(senha.isNotEmpty && senha == confirma, 'As duas senhas são iguais'),
    ];

/// Primeira regra que falta, ou null se a senha esta boa.
String? problemaSenha(String senha, String confirma) {
  if (senha.length > 72) return 'A senha pode ter no máximo 72 caracteres.';
  for (final r in regrasSenha(senha, confirma)) {
    if (!r.ok) return 'Senha: ${r.texto.toLowerCase()}.';
  }
  return null;
}

/// Telefone e opcional. Se preenchido: DDD + numero (10 ou 11 digitos).
String? problemaTelefone(String telefone) {
  var n = telefone.replaceAll(RegExp(r'\D'), '');
  if (n.isEmpty) return null;
  if (n.startsWith('55') && n.length > 11) n = n.substring(2);
  if (n.length < 10 || n.length > 11) {
    return 'Telefone inválido. Use DDD + número, ex.: (55) 99999-9999.';
  }
  return null;
}

/// (55) 99999-9999 a partir do que foi digitado.
String mascararTelefone(String valor) {
  var n = valor.replaceAll(RegExp(r'\D'), '');
  if (n.length > 11) n = n.substring(0, 11);
  if (n.length > 6) {
    return '(${n.substring(0, 2)}) ${n.substring(2, n.length - 4)}-${n.substring(n.length - 4)}';
  }
  if (n.length > 2) return '(${n.substring(0, 2)}) ${n.substring(2)}';
  return n;
}

bool emailValido(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
