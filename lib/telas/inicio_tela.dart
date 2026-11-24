// =====================================================================
// inicio_tela.dart - menu de baixo: Galpoes, Aparelho, Assinatura, Perfil
// =====================================================================

import 'package:flutter/material.dart';

import 'assinatura_tela.dart';
import 'bluetooth_tela.dart';
import 'galpoes_tela.dart';
import 'perfil_tela.dart';

class InicioTela extends StatefulWidget {
  const InicioTela({super.key});

  @override
  State<InicioTela> createState() => _InicioTelaState();
}

class _InicioTelaState extends State<InicioTela> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: [
          const GalpoesTela(),
          // so liga o Bluetooth quando a aba e aberta
          _aba == 1 ? const BluetoothTela() : const SizedBox.shrink(),
          _aba == 2 ? const AssinaturaTela() : const SizedBox.shrink(),
          _aba == 3 ? const PerfilTela() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_work_outlined), selectedIcon: Icon(Icons.home_work), label: 'Galpões'),
          NavigationDestination(icon: Icon(Icons.bluetooth), selectedIcon: Icon(Icons.bluetooth_connected), label: 'Aparelho'),
          NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'Assinatura'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
