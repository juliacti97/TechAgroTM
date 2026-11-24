# TECH AGROTM — aplicativo Flutter

Aplicativo do produtor. Ele **não acessa o banco direto**: chama a mesma API PHP do site
(`TechAgroTM-php/api`). Por isso os dados são sempre os mesmos no app, no painel web e no dashboard
do admin. As regras de negócio (senha, telefone, número de série único, assinatura, Pix) ficam no
servidor; o app confere as mesmas regras antes de enviar, só para avisar mais rápido.

```
App Flutter ──HTTP──> API PHP (XAMPP / VM / Render) ──> banco (TiDB Cloud)
     │
     └──Bluetooth──> aparelho ESP32 (Wi-Fi, servidor, criação, leitura ao vivo)
```

## O que o app faz

| Aba | Igual ao site | O que tem |
|---|---|---|
| Login | Entrar / Primeiro acesso | Nome, e-mail, telefone, propriedade, senha + confirmação (8+ caracteres, letra e número) |
| Galpões | Painel | Lista com a última leitura, online/sem sinal, atualiza a cada 15 s; adicionar galpão (série, nome, criação, UF/cidade) |
| Detalhe do galpão | Painel | Indicadores, gráficos de temperatura e umidade (1 h a 7 dias) com a faixa ideal, criação, clima lá fora, alertas, renomear, trocar cidade, desvincular |
| Aparelho | (só no app) | Bluetooth: procura o aparelho, leitura em tempo real, envia Wi-Fi, servidor e criação |
| Assinatura | Assinatura | Planos, quantidade de aparelhos, Pix com QR Code e copia-e-cola, simular pagamento, histórico |
| Perfil | Meu perfil | Editar dados e senha (pede a senha atual), sair. A conta não pode ser excluída pelo usuário |

## Como gerar o APK

### Opção A — no PC (Windows)
Precisa do Flutter instalado (`flutter doctor` sem erros, com Android SDK).

1. Coloque esta pasta em um lugar fácil, por exemplo `C:\projetos\TechAgroTM-app`.
2. Dê dois cliques em **`preparar.bat`** (ou rode no terminal). Ele faz tudo sozinho:
   cria as pastas `android/` e `ios/`, baixa as bibliotecas, cola as permissões
   (Bluetooth, internet e `http://`) e gera o APK.
3. O APK fica em `build\app\outputs\flutter-apk\app-release.apk`. Mande para o celular e instale
   (libere "instalar apps desconhecidos").

Para o APK já sair apontando para o seu servidor:

```
preparar.bat http://192.168.0.10/TechAgroTM-php/api/index.php
```

Para testar direto no celular ligado no cabo (modo depurador): `flutter run`.

### Opção B — no GitHub, sem instalar nada
1. Suba esta pasta para um repositório no GitHub (ela já tem `.github/workflows/apk.yml`).
2. Em **Actions → Gerar APK → Run workflow**, informe o endereço da API (opcional).
3. No fim (uns 5 a 8 minutos), baixe o APK em **Artifacts**.

Para não digitar o endereço toda vez: **Settings → Secrets and variables → Actions → Variables**,
crie `API_URL`. Todo push na `main` gera um APK novo.

> O endereço também pode ser trocado **dentro do app**, no ícone de servidor da tela de login,
> sem gerar outro APK.

## Qual servidor o app usa

Na tela de login, toque no ícone de servidor (canto superior direito) e informe o endereço da API:

| Onde está a API | Endereço no app |
|---|---|
| XAMPP no PC, app no **emulador** Android | `http://10.0.2.2/TechAgroTM-php/api/index.php` (padrão) |
| XAMPP no PC, app no **celular** (mesmo Wi-Fi) | `http://IP-DO-PC/TechAgroTM-php/api/index.php` (veja o IP com `ipconfig`) |
| VM do OpenNebula | `http://IP-DA-VM/api/index.php` (ou com a pasta do projeto, se houver) |
| Render (internet) | `https://seu-site.onrender.com/api/index.php` |

No celular de verdade, libere o Apache no firewall do Windows para o celular alcançar o PC.

## Bluetooth com o aparelho (ESP32)

O app segue o protocolo do firmware (`firmware/TechAgroTM/TechAgroTM.ino`, seção 4):

| Característica | Tipo | Conteúdo |
|---|---|---|
| `a1b2c3d4-0002-…` LEITURA | notify | JSON `{"t","u","sit","msg","perfil","neb","itu"}` |
| `a1b2c3d4-0003-…` PERFIL | write | `corte_s1` |
| `a1b2c3d4-0004-…` REDE | write | `NomeDaRede|senha` |
| `a1b2c3d4-0005-…` NUVEM | write | `servidor|chave` |

Passo a passo de instalação de um aparelho novo:

1. No app, aba **Galpões** → **Adicionar galpão** com o número de série (etiqueta ou 4ª tela do visor).
2. Aba **Aparelho** → **Procurar** → toque no `AgroTM-XXXXXX` → envie o **Wi-Fi** do galpão.
3. Se a API não for a padrão do firmware, envie também o **servidor** (só o domínio ou `http://IP`).
4. Em até 1 minuto a leitura aparece no app **e** no site.

**Atenção ao caminho da API no firmware:** o aparelho junta o servidor com o `CAMINHO_API` gravado em
`firmware/TechAgroTM/src/config.h` (padrão `/TechAgroTM/api/index.php`). Se a pasta no XAMPP se chama
`TechAgroTM-php`, mude para `/TechAgroTM-php/api/index.php` e grave o firmware de novo. No Render,
use `/api/index.php`.

Trocar a criação pela aba Aparelho envia para o aparelho **e** para a conta (senão o servidor desfaz a troca).

## Estrutura

```
lib/
├─ main.dart              tema e troca automática entre login e app
├─ config.dart            servidor padrão e UUIDs do Bluetooth
├─ core/
│   ├─ api.dart           todas as rotas da API PHP
│   ├─ sessao.dart        token, nome e servidor salvos no celular
│   ├─ validacao.dart     regras de senha e telefone (iguais ao servidor)
│   ├─ modelos.dart       Galpão, Leitura, Alerta, Plano, Assinatura…
│   ├─ situacoes.dart     nomes e cores das situações
│   ├─ formatos.dart      números, R$ e datas em pt-BR
│   └─ estado.dart        sessão, API e criações compartilhadas
├─ ble/aparelho_ble.dart  conversa com o ESP32
├─ telas/                 login, galpões, detalhe, adicionar, Bluetooth, assinatura, perfil
└─ widgets/               campos de formulário e gráfico de linha
tool/preparar.dart        cola as permissões no Android/iOS
preparar.bat              gera o APK no Windows
.github/workflows/apk.yml gera o APK no GitHub
```

## Bibliotecas

| Biblioteca | Para quê |
|---|---|
| `http` | chamar a API |
| `shared_preferences` | manter o login e o servidor salvos |
| `flutter_blue_plus` | Bluetooth (BLE) |
| `qr_flutter` | QR Code do Pix |

O `flutter_blue_plus` (versão 2.x) usa uma licença própria: é **grátis para uso pessoal e instituições
de ensino** (o app usa `License.nonprofit`). Uso comercial por empresa exige comprar a licença comercial
da biblioteca. Os gráficos são desenhados pelo próprio app, sem biblioteca extra.

## Problemas comuns

- **"Sem conexão com o servidor"**: confira o endereço (ícone de servidor no login), se o Apache está ligado
  e se o celular está na mesma rede do PC. No Android com `http://`, falta o `usesCleartextTraffic`.
- **Login cai sozinho**: o token venceu (30 dias) ou o `JWT_SEGREDO` do servidor mudou.
- **Bluetooth não acha o aparelho**: use celular de verdade, ligue o Bluetooth e libere a permissão
  "Dispositivos próximos". No iPhone, o aparelho precisa anunciar o serviço BLE (o firmware já faz isso).
- **Leitura aparece no Bluetooth mas não no app/site**: o Wi-Fi não conectou, o servidor está errado ou o
  `CAMINHO_API` do firmware não bate com a pasta da API.
