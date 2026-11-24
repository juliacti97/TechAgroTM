// =====================================================================
// config.dart - valores fixos do aplicativo
// =====================================================================

/// Endereco padrao da API. Pode ser trocado na tela de login
/// ("Servidor"), sem recompilar o app.
///   - Emulador Android + XAMPP no mesmo PC: http://10.0.2.2/...
///   - Celular de verdade: use o IP do PC na rede (ex.: 192.168.0.10)
///     ou o endereco do servidor na internet.
/// Usamos "index.php" no caminho para funcionar mesmo sem o .htaccess.
/// Na hora de gerar o APK da para trocar sem mexer no codigo:
///   flutter build apk --dart-define=API_URL=http://192.168.0.10/TechAgroTM-php/api/index.php
const String servidorPadrao = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2/TechAgroTM-php/api/index.php',
);

/// Bluetooth (BLE) do aparelho Sentinela AgroTM S1.
/// Os mesmos UUIDs do firmware (firmware/TechAgroTM/TechAgroTM.ino, secao 4).
class BleUuids {
  static const String servico = 'a1b2c3d4-0001-4000-8000-a62070000001';
  static const String leitura = 'a1b2c3d4-0002-4000-8000-a62070000002'; // notify: JSON da leitura
  static const String perfil = 'a1b2c3d4-0003-4000-8000-a62070000003';  // write: "corte_s1"
  static const String rede = 'a1b2c3d4-0004-4000-8000-a62070000004';    // write: "NomeDaRede|senha"
  static const String nuvem = 'a1b2c3d4-0005-4000-8000-a62070000005';   // write: "servidor|chave"
}

/// O aparelho se anuncia como "AgroTM-" + os ultimos 6 digitos do numero de serie.
const String prefixoNomeBle = 'AgroTM-';
