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

O padrão é o site no Render (`https://techagrotm-website.onrender.com/api/index.php`). Para trocar sem gerar
outro APK: na tela de login, toque no ícone de servidor (canto superior direito). O botão **Testar conexão**
confere se o endereço responde.

| Onde está a API | Endereço no app |
|---|---|
| Render (internet) | `https://SEU-SITE.onrender.com/api/index.php` |
| XAMPP no PC, app no **celular** (mesmo Wi-Fi) | `http://IP-DO-PC/TechAgroTM-php/api/index.php` (veja o IP com `ipconfig`) |
| XAMPP no PC, app no **emulador** Android | `http://10.0.2.2/TechAgroTM-php/api/index.php` |

O banco é um só (TiDB): conta, galpões e leituras são os mesmos no app, no site e no dashboard,
desde que o app e o site usem a mesma API (ou APIs ligadas ao mesmo banco).

No Render grátis o servidor "dorme": o primeiro acesso pode levar até 1 minuto.

## Bluetooth com o aparelho (ESP32)

O app funciona com as duas versões do firmware:

| | Firmware 1.x (`TechAgroTM.ino` do aparelho) | Firmware 2.0 (pasta `firmware/` do site) |
|---|---|---|
| UUIDs | `a1b2c3d4-000N-4000-8000-a6e07000000N` | `a1b2c3d4-000N-4000-8000-a6207000000N` |
| Nome Bluetooth | `AgroTM-` + **começo** do número de série | `AgroTM-` + **fim** do número de série |
| Trocar servidor pelo app | só a partir da **1.1** | sim (só o domínio) |

| N | Característica | Tipo | Conteúdo |
|---|---|---|---|
| 1 | serviço | — | — |
| 2 | LEITURA | read/notify | JSON `{"serie","fw","t","u","sit","msg","perfil","neb","itu"}` (`serie` e `fw` a partir da 1.1) |
| 3 | PERFIL | write | `corte_s1` |
| 4 | REDE | write | `NomeDaRede|senha` |
| 5 | NUVEM | write | `servidor` ou `servidor|chave` |
| 6 | HISTORICO | read/write | lê `{"serie","perfil","total","agora","leituras":[{"e","t","u","s"}]}`; responde `ok:<e>:<n>` (1.2+) |

A busca não filtra pelo serviço (alguns celulares não recebem o UUID no anúncio); a lista mostra quem
tem nome `AgroTM-…`. Se não aparecer, ligue **Mostrar todos os dispositivos Bluetooth**.

**Ponte pelo celular (firmware 1.2+):** com a aba **Aparelho** aberta e conectada, se o aparelho estiver sem
internet o app busca as leituras guardadas nele (característica 6, HISTORICO) a cada 20 s, manda para o site
(`POST /leituras/lote` com `conexao: bluetooth`) e só então pede para o aparelho apagar. Nada se perde se o
celular também estiver sem internet: as leituras continuam no aparelho.

Passo a passo de instalação de um aparelho novo:

1. Aba **Aparelho** (ou **Configurar aparelho pelo Bluetooth** na tela de login) → **Procurar** → toque no `AgroTM-…`.
2. Veja o **número de série** e toque em **Cadastrar como galpão na minha conta** (precisa estar logado).
3. Envie o **Wi-Fi** do galpão.
4. Confira o **servidor** (já vem igual ao do app) e envie. Firmware 1.1: o aparelho completa com `/api/v1/leituras`.
5. Em até 1 minuto a leitura aparece no app **e** no site.

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
assets/                   ícone e logo do app (icone.png gera o ícone com flutter_launcher_icons)
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
- **Leitura aparece no Bluetooth mas não no app/site**: o Wi-Fi não conectou, o servidor do aparelho é
  diferente do servidor do app, ou o galpão não foi cadastrado com o número de série (o Monitor Serial
  mostra "HTTP 404").
- **Conta criada no site não entra no app**: o app está em outro servidor. Use o mesmo endereço do site.
