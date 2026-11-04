# Instalação — FLAccess 0.2.0 — experimental

Pacote único, com leitor e gameplay divididos em componentes Sider.
Três pastas: content, modules, sider. Leitor base sempre ativo.

1. Feche o jogo antes de carregar atualização. Faça backup do sider.ini,
   INIs, WAVs e perfis de câmera personalizados.
2. Mescle content e modules no SiderAddons, preservando demais mods.
3. Preserve Sider 7.3.3 compatível já instalado. Pasta sider do ZIP conserva
   a mesma DLL da 0.1.9. Em instalação sem essa base, destino da DLL é
   SiderAddons/sider.dll, na raiz. Não trocar outra versão sem verificar.
4. Na seção [sider], substitua somente entradas FLAccess antigas pelas 31
   linhas lua.module do sider.ini.snippet, na ordem fornecida. Não carregar
   também FlAccessReader/FlAccessReader.lua ou FlAccessGameplay/FlAccessGameplay.lua.
5. Remova somente cpk.root antigos de FlAccessReader e FlAccessGameplay.
   Recursos próprios são lidos diretamente de content/FlAccess.
6. Preserve valores read_tooltips, use_text_assets e tackle_* anteriores em
   modules/FlAccess/FlAccess.ini. Não sobrescreva preferências com padrões do ZIP.
7. Copie WAVs personalizados para content/FlAccess/sounds; perfis camera_00.ini
   até 09 para content/FlAccess/cameras. Catálogos ficam em content/FlAccess/text.
8. Inicie pelo Sider normalmente. Painel único FLAccess; controles preservados.

No checkout: python tools/install_flaccess.py --sider <caminho-SiderAddons>.
Script registra backup e migra configurações/recursos; Python não é necessário
para jogar. Diretórios antigos ficam como backup, com entradas desativadas.

DLLs em modules/FlAccess/bin; licenças em licenses e COPYING.OpenAL.
Prism compilado do repositório oficial; commit/hash em PRISM-SOURCE.json.
Comunicação de voz continua síncrona em Lua, sem novo processo ou DLL de fala.
Controles individuais de sons e avisos são futuros; não entram nesta mudança.

Base investigada FL2026/Sider 7.3.3; compatibilidade FL27 experimental e parcial.
Publicação 0.2.0 baseada em Reader 52/Gameplay 19. Listas continuam com relato de
lentidão e há opções de outros módulos Sider sem leitura no FL27. Consulte as
notas/pendências da versão antes de atualizar. Publicações anteriores preservadas.
