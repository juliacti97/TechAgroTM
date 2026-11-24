// =====================================================================
// TECH AGROTM - aplicativo do produtor
// Usa a mesma API PHP do site: o que o produtor faz aqui aparece no
// painel web e vice-versa. Conversa com o aparelho por Bluetooth.
// =====================================================================

import 'package:flutter/material.dart';

import 'core/estado.dart';
import 'core/situacoes.dart';
import 'telas/inicio_tela.dart';
import 'telas/login_tela.dart';

/// Usada para fechar as telas abertas quando a sessao acaba (token vencido).
final GlobalKey<NavigatorState> chaveNavegador = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await sessao.carregar();
  sessao.addListener(() {
    if (!sessao.logado) chaveNavegador.currentState?.popUntil((rota) => rota.isFirst);
  });
  runApp(const TechAgroApp());
}

class TechAgroApp extends StatelessWidget {
  const TechAgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = ColorScheme.fromSeed(
      seedColor: Cores.ambar,
      primary: Cores.grafite,
      secondary: Cores.ambar,
      surface: Colors.white,
    );
    return MaterialApp(
      title: 'TECH AGROTM',
      navigatorKey: chaveNavegador,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: esquema,
        useMaterial3: true,
        scaffoldBackgroundColor: Cores.papel,
        appBarTheme: const AppBarTheme(
          backgroundColor: Cores.grafite,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      // troca de tela sozinho quando a pessoa entra ou sai
      home: ListenableBuilder(
        listenable: sessao,
        builder: (context, _) => sessao.logado ? const InicioTela() : const LoginTela(),
      ),
    );
  }
}
