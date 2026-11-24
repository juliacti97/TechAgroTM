// =====================================================================
// config.dart - valores fixos do aplicativo
// =====================================================================

/// Endereco padrao da API (o site no Render). Pode ser trocado na tela de
/// login ("Servidor"), sem recompilar o app.
///   - Emulador Android + XAMPP no mesmo PC: http://10.0.2.2/...
///   - Celular de verdade: use o IP do PC na rede (ex.: 192.168.0.10)
///     ou o endereco do servidor na internet.
/// Usamos "index.php" no caminho para funcionar mesmo sem o .htaccess.
/// Na hora de gerar o APK da para trocar sem mexer no codigo:
///   flutter build apk --dart-define=API_URL=http://192.168.0.10/TechAgroTM-php/api/index.php
const String servidorPadrao = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://techagrotm-website.onrender.com/api/index.php',
);

/// Bluetooth (BLE) do aparelho Sentinela AgroTM S1.
/// Existem duas versoes de firmware, com UUIDs quase iguais:
///   - 1.x (o TechAgroTM.ino gravado no aparelho): ...-8000-a6e07000000N
///   - 2.0 (pasta firmware/ do site):                ...-8000-a6207000000N
/// O app aceita as duas. N: 1 servico, 2 leitura, 3 perfil, 4 rede, 5 nuvem.
class BleUuids {
  static const List<String> familias = ['a6e07', 'a6207'];

  static String uuid(String familia, int n) => 'a1b2c3d4-000$n-4000-8000-${familia}000000$n';

  static const int servico = 1, leitura = 2, perfil = 3, rede = 4, nuvem = 5;
}

/// O aparelho se anuncia como "AgroTM-" + 6 caracteres do numero de serie
/// (o firmware 1.x usa o COMECO do numero, o 2.0 usa o FIM).
const String prefixoNomeBle = 'AgroTM-';
