// =====================================================================
// formatos.dart - numeros, dinheiro e datas no jeito brasileiro
// (feito a mao para nao precisar de mais uma biblioteca)
// =====================================================================

String _dois(int n) => n.toString().padLeft(2, '0');

/// 23.456 -> "23,5"  (null -> "—")
String numero(num? valor, [int casas = 1]) =>
    valor == null ? '—' : valor.toStringAsFixed(casas).replaceAll('.', ',');

/// 1234.5 -> "R$ 1.234,50"
String reais(num valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAll('-', '');
  final grupos = <String>[];
  for (var i = inteiro.length; i > 0; i -= 3) {
    grupos.insert(0, inteiro.substring(i - 3 < 0 ? 0 : i - 3, i));
  }
  return '${valor < 0 ? '-' : ''}R\$ ${grupos.join('.')},${partes[1]}';
}

/// Le uma data da API. Aceita ISO com "Z" ("2026-11-19T23:00:00.000Z")
/// ou o formato do banco em UTC ("2026-11-19 23:00:00"). Devolve hora local.
DateTime? lerData(dynamic valor) {
  if (valor == null) return null;
  var texto = valor.toString().trim();
  if (texto.isEmpty) return null;
  if (!texto.contains('T')) texto = texto.replaceFirst(' ', 'T');
  // so data ("2026-11-19"): e um dia, nao um instante
  if (texto.length == 10) return DateTime.tryParse(texto);
  if (!texto.endsWith('Z') && !texto.contains('+')) texto = '${texto}Z';
  return DateTime.tryParse(texto)?.toLocal();
}

String hora(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';
String dia(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}/${d.year}';
String diaCurto(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}';
String diaHora(DateTime d) => '${diaCurto(d)} ${hora(d)}';

/// "agora mesmo", "há 5 min", "há 2 h", "há 3 d"
String haQuanto(DateTime d) {
  final min = DateTime.now().difference(d).inMinutes;
  if (min < 1) return 'agora mesmo';
  if (min < 60) return 'há $min min';
  final h = min ~/ 60;
  return h < 24 ? 'há $h h' : 'há ${h ~/ 24} d';
}

/// Converte um valor do JSON em double (a API pode mandar int ou texto).
double? paraDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int paraInt(dynamic v, [int padrao = 0]) {
  if (v == null) return padrao;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? padrao;
}

bool paraBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
