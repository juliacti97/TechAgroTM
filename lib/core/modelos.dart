// =====================================================================
// modelos.dart - os dados que vem da API, ja convertidos
// Os nomes dos campos sao os mesmos do JSON da API (api/*.php).
// =====================================================================

import 'formatos.dart';

/// Criacao monitorada (GET /perfis): faixa ideal de cada animal e fase.
class Perfil {
  final String id, grupo, especie, fase;
  final double tMin, tMax, uMin, uMax, critFrio, critCalor;
  final bool usaItu;

  Perfil.deJson(Map<String, dynamic> j)
      : id = j['id'].toString(),
        grupo = (j['grupo'] ?? '').toString(),
        especie = (j['especie'] ?? '').toString(),
        fase = (j['fase'] ?? '').toString(),
        tMin = paraDouble(j['tMin']) ?? 0,
        tMax = paraDouble(j['tMax']) ?? 0,
        uMin = paraDouble(j['uMin']) ?? 0,
        uMax = paraDouble(j['uMax']) ?? 0,
        critFrio = paraDouble(j['critFrio']) ?? 0,
        critCalor = paraDouble(j['critCalor']) ?? 0,
        usaItu = paraBool(j['usaITU']);

  String get nome => '$especie · $fase';

  static const nomesGrupos = {'aves': 'Aves', 'suinos': 'Suínos', 'bovinos': 'Bovinos', 'equinos': 'Equinos'};
}

/// Galpao / aparelho (GET /aparelhos), com a leitura mais recente.
class Aparelho {
  final String numeroSerie, apelido, perfil;
  final String? localNome, situacao, conexao;
  final double? temperatura, umidade, itu;
  final DateTime? registradoEm;
  final bool online, perfilPendente, temLocal;
  final Perfil? faixa;

  Aparelho.deJson(Map<String, dynamic> j)
      : numeroSerie = j['numero_serie'].toString(),
        apelido = (j['apelido'] ?? '').toString(),
        perfil = (j['perfil'] ?? '').toString(),
        localNome = j['local_nome']?.toString(),
        situacao = j['situacao']?.toString(),
        conexao = j['conexao']?.toString(),
        temperatura = paraDouble(j['temperatura']),
        umidade = paraDouble(j['umidade']),
        itu = paraDouble(j['itu']),
        registradoEm = lerData(j['registrado_em']),
        online = paraBool(j['online']),
        perfilPendente = paraBool(j['perfil_pendente']),
        temLocal = j['latitude'] != null && j['longitude'] != null,
        faixa = j['faixa'] is Map<String, dynamic> ? Perfil.deJson(j['faixa'] as Map<String, dynamic>) : null;

  String get nome => apelido.isNotEmpty ? apelido : numeroSerie;
  bool get temLeitura => temperatura != null;

  /// Texto do estado da conexao (igual ao site).
  String get textoConexao {
    const vias = {
      'wifi': 'pelo Wi-Fi',
      'cabo': 'pelo cabo de rede',
      'bluetooth': 'pelo celular (Bluetooth)',
      'lote': 'leituras recuperadas após queda de internet',
    };
    final via = vias[conexao];
    if (online) return via == null ? 'Aparelho online' : 'Aparelho online · $via';
    if (registradoEm == null) return 'Aguardando a primeira leitura';
    return 'Sem sinal. O aparelho guarda as leituras e envia quando a conexão voltar.';
  }

  /// Os 6 ultimos caracteres do numero de serie: e o que aparece no nome
  /// Bluetooth do aparelho ("AgroTM-XXXXXX").
  String get sufixoBle =>
      numeroSerie.length > 6 ? numeroSerie.substring(numeroSerie.length - 6) : numeroSerie;
}

/// Ponto do grafico (GET /leituras/{serie}?horas=N).
class Leitura {
  final DateTime em;
  final double temperatura, umidade;
  final double? tmin, tmax;

  Leitura.deJson(Map<String, dynamic> j)
      : em = lerData(j['em'] ?? j['registrado_em']) ?? DateTime.now(),
        temperatura = paraDouble(j['temperatura']) ?? 0,
        umidade = paraDouble(j['umidade']) ?? 0,
        tmin = paraDouble(j['tmin']),
        tmax = paraDouble(j['tmax']);
}

/// Alerta (GET /alertas).
class Alerta {
  final String numeroSerie, situacao, mensagem;
  final String? apelido;
  final DateTime? em;

  Alerta.deJson(Map<String, dynamic> j)
      : numeroSerie = (j['numero_serie'] ?? '').toString(),
        situacao = (j['situacao'] ?? '').toString(),
        mensagem = (j['mensagem'] ?? '').toString(),
        apelido = j['apelido']?.toString(),
        em = lerData(j['em'] ?? j['criado_em']);
}

/// Conta do produtor (GET /perfil).
class Conta {
  final int id;
  final String nome, email, telefone, propriedade, tipo;
  final DateTime? criadoEm;

  Conta.deJson(Map<String, dynamic> j)
      : id = paraInt(j['id']),
        nome = (j['nome'] ?? '').toString(),
        email = (j['email'] ?? '').toString(),
        telefone = (j['telefone'] ?? '').toString(),
        propriedade = (j['propriedade'] ?? '').toString(),
        tipo = (j['tipo'] ?? 'produtor').toString(),
        criadoEm = lerData(j['criado_em']);
}

/// Plano a venda (GET /planos).
class Plano {
  final int id, meses;
  final String nome, descricao;
  final double preco;

  Plano.deJson(Map<String, dynamic> j)
      : id = paraInt(j['id']),
        meses = paraInt(j['meses'], 1),
        nome = (j['nome'] ?? '').toString(),
        descricao = (j['descricao'] ?? '').toString(),
        preco = paraDouble(j['preco']) ?? 0;
}

/// Compra de assinatura (GET/POST /assinaturas).
class Assinatura {
  final int id, quantidade;
  final String plano, status;
  final double valor;
  final String? pixCopiaCola;
  final DateTime? criadoEm;
  final DateTime? inicio, fim;   // datas (sem hora)

  Assinatura.deJson(Map<String, dynamic> j)
      : id = paraInt(j['id']),
        quantidade = paraInt(j['quantidade'], 1),
        plano = (j['plano'] ?? '').toString(),
        status = (j['status'] ?? '').toString(),
        valor = paraDouble(j['valor']) ?? 0,
        pixCopiaCola = j['pix_copia_cola']?.toString(),
        criadoEm = lerData(j['criado_em']),
        inicio = lerData(j['inicio']),
        fim = lerData(j['fim']);

  static const nomesStatus = {
    'pendente': 'Aguardando Pix',
    'ativa': 'Ativa',
    'cancelada': 'Cancelada',
    'expirada': 'Expirada',
  };
  String get nomeStatus => nomesStatus[status] ?? status;
}

/// Resposta de GET /assinaturas.
class MinhasAssinaturas {
  final Assinatura? atual, pendente;
  final List<Assinatura> historico;
  final bool pagamentoSimulado;

  MinhasAssinaturas.deJson(Map<String, dynamic> j)
      : atual = j['atual'] is Map<String, dynamic> ? Assinatura.deJson(j['atual'] as Map<String, dynamic>) : null,
        pendente = j['pendente'] is Map<String, dynamic> ? Assinatura.deJson(j['pendente'] as Map<String, dynamic>) : null,
        historico = (j['historico'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Assinatura.deJson)
            .toList(),
        pagamentoSimulado = paraBool(j['pagamento_simulado']);
}

/// Estado (UF) e cidade (GET /localidades/...).
class Uf {
  final String sigla, nome;
  Uf.deJson(Map<String, dynamic> j)
      : sigla = j['sigla'].toString(),
        nome = (j['nome'] ?? '').toString();
}

class Cidade {
  final int id;
  final String nome;
  Cidade.deJson(Map<String, dynamic> j)
      : id = paraInt(j['id']),
        nome = (j['nome'] ?? '').toString();
}
