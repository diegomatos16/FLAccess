# FLAccess 0.2.0 — primeira etapa local, 30/10/2026

Atualização posterior: build44 com29 módulos e agrupador comum. Ver
[retorno43 e ajustes44](READER-DEV44-2026-10-30.pt-BR.md). Dados abaixo
registram entrega inicial build43 e seus testes.

## Entrega

Um FLAccess com 28 módulos Sider normais, sem loader próprio: core;
16 componentes do leitor; política de áudio, registro nativo e câmera;
oito componentes de gameplay. Ordem exata em modules/FlAccess/components.json
e packaging/sider.ini.snippet. Leitor base obrigatório, sem novo liga/desliga.
Sons/avisos individualmente configuráveis ficam para futuro.

Recursos em content/FlAccess: sons, catálogos PT/EN e perfis por câmera.
Não há substituição nativa que exija LiveCPK para esses arquivos; foram retiradas
somente as duas referências cpk.root antigas do FLAccess na instalação.
Sider DLL preservada, SHA256
57005a0e5977e699c8053293163599508616fd78e044b0f4ccd8ca8e2ccab116.

## Fontes e limites desta etapa

Arquivos modules/FlAccess/*.lua são fontes mantidos e módulos instalados.
Cada um tem init(ctx); install(ctx) monta os serviços antes de iniciar hooks.
Estado antes lexical foi promovido a ctx.flaccess.reader/gameplay por migração
sintática que distingue escopos, variáveis sombreadas, strings e chaves.
Funções internas continuam com seus locais próprios. Este primeiro passo
preserva o comportamento; não significa eliminação de todo acoplamento.

Leitor conserva16 fronteiras da base42. Gameplay separa estado, regras,
memória, saída de áudio, leitura da partida, diagnóstico, renderização e ciclo
de vida. Registro/câmera/política de áudio são serviços próprios. Somente os
componentes de ciclo de vida registram callbacks; não há registro duplicado
display_frame dentro do mesmo módulo. Painel identificado como FLAccess.

Manter seleção nativa e fila única de leitura, limite de duas tentativas,
revalidação de foco, normalização cdata e leituras seguras. Nenhuma escrita
de cursor/resultado de janela foi reintroduzida. Gameplay experimental16
preserva regras e assets, sem nova aprovação audível presumida.

INIs anteriores migram para FlAccess.ini. Salvar opções do leitor preserva
tackle_* e linhas desconhecidas. Instalador conserva WAVs e perfis editados,
validação de jogador local, Sider DLL, demais mods e cópias antigas desativadas.
Backups completos de código antes da migração em
local-backups/2026-10-30-before-flaccess020; instalação registra backup próprio
e INSTALL.json com hashes. Não ativar módulos antigos junto dos novos.

## Prism atualizado pelo repositório

Fonte oficial https://github.com/ethindp/prism, commit
70731bcb9837c90ff84ce401f244c0c4a8c7134c (master consultado em30/10/2026).
DLL x64 compilada localmente, versão0.18.3, fonte upstream sem alterações.
SHA256 a41e0fdde42b0cf8916ae9e587a2f15f046e96c68421b4e99627ff284fd0add2.
Headers da mesma compilação, LICENSE/NOTICE e licenças transitivas incluídos.
Metadados em modules/FlAccess/PRISM-SOURCE.json. Binding confere exports e
registra prism_version_string. ABI C: IDs/features64bits, size_t nativo,
bool de um byte, texto UTF8 terminado em zero. Comunicação permanece síncrona
em Lua por escolha anterior; não há novo worker ou DLL de fala.

Build em tools/build_prism_source.cmd, MSVC x64. ATL ausente foi extraído para
.build/atl de pacotes VSIX oficiais Microsoft, com SHA256 do catálogo instalado
verificado. Não foi alterada instalação Visual Studio. A tentativa inicial de
instalação silenciosa terminou5007 (processo sem elevação); extração local
resolveu a dependência. Backend JAWS/SAPI/NVDA mantidos. CTest do upstream
não descobriu testes nesta configuração; não registrar como suíte aprovada.

## Testes

-410 testes comportamentais no leitor modular real; incluem RPM Windows,
  ponteiros cdata, países, registros, fila/foco e fluxos simulados.
-65 testes Python (59 do projeto e6 da extração de textos): contratos nativos anteriores, pacote determinístico,
  manifesto, migração de INI/assets, idempotência e ABI/registro real do Prism.
-104 contratos de gameplay sobre os oito componentes novos.
-191 contratos de câmera sobre camera.lua novo, com oráculo NDC independente.
- Integração dos28 módulos em ambientes Sider separados,16 eventos customizados,
  23 registros do leitor,120 callbacks, Prism nativo, textos PT/EN, reset,
  preservação de configuração, rejeição de ordem incorreta e fallback de câmera.
- Extração limpa do ZIP repete integração dos28 módulos e Prism/recursos.
- Gameplay integrado com memória sintética e WAV/OpenAL/HRTF reais: bola,
  laterais, gols, posse, passe, desarme, mudo, pausa/reentrada e recuperação.
  Renderiza PCM offline; não equivale a ouvir efeitos dentro do jogo.

Logs em tests/flaccess020-*.log e tests/prism020-source-build.log.
Pacote local release/0.2.0-local/FlAccess.zip. Nenhuma publicação, tag ou push.
Release0.1.9 e seus assets permanecem intactos.

## Validação real pendente

Testes não provam FPS, audição ou ausência universal de crashes. Integração
de28 módulos usa assinaturas sintéticas que desativam leitura espacial do jogo;
pipeline ativo de gameplay é coberto em fixture própria. Passagem real com
leitor e gameplay ativos juntos ainda precisa de navegação/audição no FL2026.
Não encerrar problemas1/6/4/25/47/51/53 ou outras pendências por estes testes.
Reabrir jogo pelo Sider e navegar normalmente; sem pausas cronometradas.

## Instalação concluída

Instalado em SiderAddons em30/10/2026. Backup de instalação:
local-backups/flaccess020-install-20261030-204812-287051.
Hashes dos28 módulos e Prism instalados conferidos. Demais linhas do sider.ini
permanecem iguais; Sider DLL preservada. Arquivos de gameplay Lua/INI/DLL
antigos coincidem com backup de fontes; README antigo instalado já diferia e
não foi sobrescrito. Recursos personalizados migrados por cópia.

Integração repetida diretamente nos módulos instalados, incluindo Prism nativo;
410 testes do leitor também passaram contra cópia instalada. Quatro cenários
de WAVs ausentes passaram no gameplay instalado. Política de áudio, ABI real
da DLL de volume e registro nativo também passaram usando arquivos instalados.
Checkout Git recebeu fontes/documentação, sem commit/push; cinco arquivos
untracked anteriores preservados por hash. Suíte Python no checkout passa com
37 testes dependentes de EXE/capturas locais ignorados; execução no workspace
do jogo teve59 testes sem skips, mais6 do extrator.
