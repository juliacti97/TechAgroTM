// =====================================================================
// tool/preparar.dart - cola as permissoes no Android e no iOS sozinho
// Roda depois do "flutter create". Pode rodar quantas vezes quiser:
// o que ja estiver no arquivo nao e colado de novo.
//   dart run tool/preparar.dart
// =====================================================================
import 'dart:io';

const permissoesAndroid = '''
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
''';

const chavesIos = '''
	<key>NSBluetoothAlwaysUsageDescription</key>
	<string>O TECH AGROTM usa o Bluetooth para configurar o aparelho do galpão.</string>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
	</dict>
''';

void main() {
  var erro = false;

  // ---------- Android ----------
  final manifesto = File('android/app/src/main/AndroidManifest.xml');
  if (!manifesto.existsSync()) {
    stderr.writeln('Nao achei ${manifesto.path}. Rode antes: flutter create --platforms android,ios .');
    erro = true;
  } else {
    var xml = manifesto.readAsStringSync();
    if (!xml.contains('android.permission.BLUETOOTH_SCAN')) {
      xml = xml.replaceFirst('<application', '${permissoesAndroid.trimLeft()}\n    <application');
    }
    if (!xml.contains('usesCleartextTraffic')) {
      // libera http:// (XAMPP / VM sem https)
      xml = xml.replaceFirst('<application', '<application\n        android:usesCleartextTraffic="true"');
    }
    xml = xml.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="TECH AGROTM"');
    manifesto.writeAsStringSync(xml);
    print('Android: permissoes OK');
  }

  // ---------- iOS (so se a pasta existir) ----------
  final plist = File('ios/Runner/Info.plist');
  if (plist.existsSync()) {
    var txt = plist.readAsStringSync();
    if (!txt.contains('NSBluetoothAlwaysUsageDescription')) {
      final fim = txt.lastIndexOf('</dict>');
      txt = txt.substring(0, fim) + chavesIos + txt.substring(fim);
      plist.writeAsStringSync(txt);
    }
    print('iOS: permissoes OK');
  }

  // ---------- teste de exemplo do flutter create (procura um contador que nao existe) ----------
  final testeExemplo = File('test/widget_test.dart');
  if (testeExemplo.existsSync()) {
    testeExemplo.deleteSync();
    print('Apagado test/widget_test.dart de exemplo');
  }

  exit(erro ? 1 : 0);
}
