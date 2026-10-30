# Núcleo comum de áudio FLAccess

Contrato permanente solicitado pelo usuário: todos os efeitos do mod, atuais e
futuros, seguem volume e mudo do FL_2026.exe no Windows. Executa dentro do jogo;
nenhum reprodutor ou processo auxiliar é instalado. NVDA continua sendo o leitor
de tela do usuário; esta base trata efeitos reproduzidos pelo mod.

`modules/FlAccessGameplay/engine/audio.lua` expõe `ctx.flaccess_audio`.
O módulo Gameplay agregado inicializa áudio antes dos consumidores.
Não carregar uma entrada FLAccess_audio.lua separada.
Cada consumidor chama `prepare_output()` antes de reproduzir e durante atualizações.
Estado indisponível exige silêncio. Para OpenAL, abrir exclusivamente por
`open_output(al)`, depois de `prepare_output()` estar pronto; não usar saída padrão
arbitrária nem criar stream antecipado. A DLL OpenAL Soft instalada é 1.25.2.
O backend WASAPI é selecionado no ambiente do processo antes de carregar OpenAL.

O núcleo C++ descobre apenas sessões com PID igual ao processo atual, obtém a saída
de uma sessão nativa ativa e prepara a sessão padrão desse processo nesse dispositivo.
O OpenAL Soft usa essa sessão WASAPI padrão (GUID_NULL). Copia grupo, volume absoluto
e mudo; notificações propagam mudanças, ignorando nosso próprio GUID para não criar
realimentação. Nunca multiplicar volume do Windows no ganho dos efeitos: isso
aplicaria atenuação duas vezes. Ganho individual/proximidade permanece separado.

Dispositivos e sessões são enumerados internamente pela DLL para vincular o áudio.
Não abre o mixer, não altera o volume do dispositivo nem sessões de outros PIDs.
Novas sessões do próprio processo são incluídas na descoberta periódica; isso é
proteção adicional, não autorização para iniciar sons fora do contrato de abertura.
Backends futuros precisam usar a mesma sessão padrão ou implementar vínculo e
preparação equivalentes antes do primeiro som. Não criar executável reprodutor.

Sem sessão nativa comprovada ou sem saída correspondente, os efeitos não começam.
Sessão expirada é removida. Falha do serviço exige reiniciar o jogo; troca de saída
durante uma partida ainda não tem migração do contexto OpenAL implementada.
Volume interno dos menus de áudio do jogo é outra camada, ainda não integrada.

Build: executar `build.cmd` com Visual Studio C++ x64 instalado. Compila `/W4 /WX`,
CRT estático, sem runtime C++ adicional para distribuir. Somente a DLL vai para
`SiderAddons/modules/FlAccessGameplay/bin`; executáveis em `audio-core/bin` são
testes locais. Após compilar, atualizar também a DLL distribuível em
`modules/FlAccessGameplay/bin` e conferir os hashes antes de empacotar.

Validações: política pura, callbacks/propagação reais com sessões COM falsas,
API Lua com ABI falso e carregamento/ABI da DLL real sem iniciar o worker.
Esses testes não comprovam audição nem integração real do Windows durante o jogo.

Validação adicional de 27/10: `build_windows_test.cmd` compila o teste opcional
`bin/test_windows_silent.exe CAMINHO_SOFT_OAL_DLL`. Ele cria uma sessão WASAPI
sintética silenciosa no seu próprio PID e verifica o núcleo com Windows real:
sessão padrão herda o master antes da abertura, OpenAL a torna ativa, volume,
mute/unmute e zero propagam. Não abre a sessão do jogo nem ajusta endpoint ou
outros aplicativos. Executável apenas de desenvolvimento; não distribuí-lo como
reprodutor do mod. Resultado em ../tests/audio-windows-silent-2026-10-27.log.

Referências técnicas:

- [OpenAL Soft 1.25.2, WASAPI](https://github.com/kcat/openal-soft/blob/1.25.2/alc/backends/wasapi.cpp): Initialize com sessão padrão.
- [IAudioClient::Initialize](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudioclient-initialize): AudioSessionGuid nulo.
- [OnSimpleVolumeChanged](https://learn.microsoft.com/en-us/windows/win32/api/audiopolicy/nf-audiopolicy-iaudiosessionevents-onsimplevolumechanged): contexto de evento e callbacks.
