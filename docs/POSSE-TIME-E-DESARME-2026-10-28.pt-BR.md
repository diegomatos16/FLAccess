# Posse do time e alerta experimental de desarme

## Gameplay experimento14 — posse do time e desarme experimental, 28/10/2026

Usuário forneceu teamStillWithBall.wav e nova versão dealertTacle.wav em LiveCPK.
Importados somente esses dois para fonte, preservados WAVs LIVE e backup do antigo
alertTacle. Escolheu SOMENTE aviso de time no passe com troca automática; não
adicionar gotBall ao assumir receptor. Desarme deve repetir enquanto houver
condição. Inicialmente rejeitou aproximação2m e pediu investigação nativa; depois
disse “se for muito difícil, usamos algum método tranquilo pra testar ver se basta”.
Essa autorização posterior permitiu versão simples; explicado em comentário que
não garante sucesso. Não tratar aproximação como condição nativa comprovada.

Implementado14/instalado: teamStillWithBall é toque único central0,4. Depois de posse
local, recebe companheiro confirmado toca esse aviso; interceptação confirmada toca
LostBall. Intervalo de bola solta no passe AGUARDA recebedor, sem perda falsa e sem
timeout arbitrário. Troca assistida antes/durante/depois da recepção não cria par
LostBall/gotBall nem duplica aviso. Trocar normalmente para quem já tem bola, sem
passe local antecedente, ainda pode avisar gotBall. Recuperação pelo mesmo jogador
também gotBall. Estado desconhecido/pausa/reentrada reinicia referência silenciosa;
mute consome eventos sem replay. Origem ANALYZE/INFO da13 preservada; ator0 válido.

alertTacle é LOOP DIRECIONAL na posição da bola, referência pela tela. Aproximação
EXPERIMENTAL: oponente com posse nativa confirmada, bola até1m de altura e diferença
vertical até1m do jogador, distânciaXZ até2m. Mantém até2,3m para evitar cortes na
borda. Não é desarme garantido nem prova de alcance/animação nativos. Só o teste
real dirá se basta. Bola amiga/solta/alta/holder desconhecido, pausa/mute/no-match
silenciam; troca de ator reinicia zona. Mesmo contexto HRTF/volume/mudo do jogo.
9sources/8buffers:6loops (um condicional) e3avisos únicos. WAV opcional ausente
silencia só respectivo som. Core/Reader/DLLs/assistência/controles intactos.

Config nova modules/FlAccessGameplay/FlAccessGameplay.ini: tackle_enabled,
tackle_distance, tackle_exit_distance, tackle_max_ball_height, tackle_volume.
Lida ao iniciar; reabrir jogo após editar. Fonte/ZIP com padrão; instalação cria
somente se ausente, preservando ajustes existentes. Sem opção no painel Sider ainda.

Pesquisa nativa: ThinkUnitTackle8bb220 chama8bb290: altura<=1 e distânciaXZ²<=225
(15m), mais comando de entrada. Isso habilita tentativa, não comprova contato.
ActionTackle971ab0/971990 gera alvo por5bebd0;971ba0 tem filtros adicionais; parâmetros
pressTackleEnableAngleIdle/Move em1e66933..1e66a2d. Não encontrado indicador contínuo
validado de alcance real. Evidência tests/tackle-native-investigation-2026-10-28.txt.
Investigação de um detector nativo mais preciso permanece possível; não alegar pronto.

104 contratos, registro/auditoria de posse, lifecycle HRTF/WAV offline passaram.
Cobre passe/bola solta/intercepção e seleção antecipada/durante/tardia, ator0,
loops reais/direção/histerese, amigo/alto/solto/unknown, pause/mute/zero/reset,
sem WAVs opcionais/novo team/Tacle. Team PCM isolado0,146743; Tacle0,175199.
2 testes pacote e extração limpa com INI passaram. Log
 tests/team-tackle-validation-2026-10-28.log. Sem audição14; não fechar relatos reais
anteriores por testes simulados. Orientação pela tela e fonteANALYZE mantidas.

Gameplay fonte/Sider 2D0DDF4B12C5E5B60B0B4AE0A26A9253567CDBE4D4D5225FC7A70A48D222A0EB. ZIP local 6f1a52e8a0165a27a31fa2c11720a71f312487ced867e9ef622a91bc5141a250,54payloads+manifesto.
Readerhash A1045EFAD88D391AD29D8DC29260A65C918E3EBD5BE2002D2D30457D8D4BE86D.
Backup emlocal-backups/2026-10-28-before-team-tackle; outras evidências preservadas.
Nada publicado/sincronizado. Reabrir jogo para teste normal; encerrar turno e
aguardar usuário, sem pausas cronometradas nem monitorar enquanto joga.
