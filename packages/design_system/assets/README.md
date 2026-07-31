# Assets do design_system

Origem: material de identidade visual em `img/` e na raiz do repositório
(`icone-kids-task.png`, `plano-de-fundo.png`), fornecido pelo proprietário do
produto. Processado uma vez (remoção de fundo de croma nos ícones, recorte,
recompressão) e versionado aqui para que o app não dependa da pasta `img/`
em tempo de build.

| Arquivo | Origem | Processamento |
|---|---|---|
| `brand/wordmark.png` | `img/tela-de-login-barra.png` | fundo verde removido (chroma key + despill), recortado |
| `coins/kidscoin.png` | `img/coin.png` | fundo magenta removido, recortado, redimensionado para 512px |
| `xp/xp_sparkle_teal.png` | `img/icon-xp-menina.png` | fundo magenta removido, recortado, redimensionado. Renomeado por cor, não por gênero — ver nota abaixo |
| `xp/xp_sparkle_violet.png` | `img/icon-xp-menino.png` | idem |
| `backgrounds/access_background.jpg` | `img/tela-de-login.png` | recomprimido em JPEG |
| `backgrounds/dashboard_banner.jpg` | `img/dashboard.png` | recomprimido em JPEG |
| `backgrounds/reports_background.jpg` | `img/tela-de-relatorio.png` | recomprimido em JPEG — reservado para a tela de relatórios (Marco 2/7, ainda não construída) |
| `backgrounds/journey_background.jpg` | `img/plano-de-fundo2.png` | recomprimido em JPEG |
| `themes/block_world_background.jpg` | `img/tema-quadriculado.png` | recomprimido em JPEG |
| `themes/space_adventure_background.jpg` | `img/tema-espaco.png` | recomprimido em JPEG |
| `themes/castles_quest_background.jpg` | `img/tema-princesas.png` | recomprimido em JPEG |

`branding/app_icon_master.png` (de `icone-kids-task.png`) e
`branding/splash_master.png` (de `plano-de-fundo.png`) não são assets de
runtime — não aparecem na lista `flutter: assets:` do `pubspec.yaml`. Servem
apenas como fonte para `flutter_launcher_icons` e `flutter_native_splash` em
tempo de build em `apps/mobile`.

## Nota sobre nomenclatura de gênero

Os arquivos originais em `img/` chamam-se `icon-xp-menina.png` e
`icon-xp-menino.png`. Visualmente são apenas duas variações de cor do mesmo
ícone abstrato (um "sparkle" de quatro pontas) — nenhum elemento gráfico
indica gênero. O Kid's Task não coleta gênero nem oferece seleção de avatar
por gênero (`CLAUDE.md`), então os nomes foram normalizados para
`xp_sparkle_teal`/`xp_sparkle_violet` neste pacote. Os arquivos originais em
`img/` não foram renomeados nem apagados.
