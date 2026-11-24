@echo off
REM ==================================================================
REM  TECH AGROTM - prepara o app e gera o APK (Windows)
REM  Uso:  preparar.bat
REM        preparar.bat http://192.168.0.10/TechAgroTM-php/api/index.php
REM  O endereco (opcional) vira o servidor padrao dentro do APK.
REM ==================================================================
cd /d "%~dp0"

where flutter >nul 2>nul || (echo Flutter nao encontrado. Instale e rode "flutter doctor". & pause & exit /b 1)

if not exist android (
  echo [1/4] Criando as pastas android e ios...
  call flutter create --org br.com.techagrotm --project-name techagrotm_app --platforms android,ios . || goto erro
) else (
  echo [1/4] Pastas android/ios ja existem.
)

echo [2/4] Baixando bibliotecas...
call flutter pub get || goto erro

echo [3/4] Colando permissoes...
call dart run tool/preparar.dart || goto erro
call dart run flutter_launcher_icons || goto erro

echo [4/4] Gerando o APK...
if "%~1"=="" (
  call flutter build apk --release || goto erro
) else (
  call flutter build apk --release --dart-define=API_URL=%~1 || goto erro
)

echo.
echo Pronto! APK em: build\app\outputs\flutter-apk\app-release.apk
explorer build\app\outputs\flutter-apk
pause
exit /b 0

:erro
echo.
echo Deu erro no passo acima. Leia a mensagem e rode "flutter doctor".
pause
exit /b 1
