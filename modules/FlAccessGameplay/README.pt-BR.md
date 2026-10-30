# FlAccessGameplay

Gameplay experimental16, incluído na versão0.1.9 por autorização do responsável.
Base FL2026. Compatibilidade com FL 27 não garantida.
Funciona sem Reader. Ativar somente `lua.module = "FlAccessGameplay\FlAccessGameplay.lua"`.

WAVs abertos e editáveis em `livecpk/FlAccessGameplay/sounds/`. Manter nome e
reabrir jogo após trocar um WAV. Nome novo exige evento implementado no código.
Assets ausentes silenciam somente o efeito correspondente. Nenhum WAV é alterado
pela normalização das laterais, realizada em memória.

Componentes internos: `engine/audio.lua`, `registry.lua`, `cameraRadars.lua` e
`radar.lua`. Perfis independentes em `engine/cameraRadars/camera_00.ini` até09.
São configurações lidas ao iniciar o jogo. Editar o INI da câmera instalada e
reabrir o jogo aplica o ajuste sem recompilar. Se faltar o arquivo, usa o padrão
incorporado. Arquivo presente inválido desativa só seu perfil; não disfarça erro
usando outro perfil. Aceita BOM UTF-8; limite4096bytes por arquivo.
Não carregar componentes diretamente no sider.ini. Runtime não usa require/loadfile.
DLLs ficam em `bin/`; estado de desenvolvimento em `state/`.

Radar segue tela, conforme escolha do usuário. Som à esquerda orienta analógico
à esquerda; frente orienta para o topo da tela. A projeção usa a perspectiva atual,
a posição do jogador controlado e as posições no campo; giro do corpo não muda
referência. Altura da bola continua como elevação sonora. Com posse própria
confirmada a bola fica centralizada. Referência do áudio original do jogo não foi
comprovada e pode ser diferente, sobretudo na câmera Jogador.

cameraRadars usa CAMERA/INFO raw+0c (matriz de visão/projeção) e MATCH/ENV raw+48
(ID nativo). Perfis0..9 separados, com mesma matemática inicial. Famílias verificadas no FL2026: ID2 fan_view, ID3 broadcast, ID5 dynamic_wide
(Dinâmica ampla), ID6 stadium (Estádio). Demais rótulos não associados; ID0 é
perfil transitório, não opção comprovada de câmera. Identificação estática da
família não equivale a calibração audível ou prova da transformação do analógico.
Perfis ajustam pan_sign (1 ou -1 para esquerda/direita), depth_sign (1 ou -1
para frente/trás) e depth_scale (0,05 a20; usar ponto decimal no INI). Padrão1
preserva o cálculo da15. Cada arquivo precisa manter native_id correspondente.
Não definir sinais por direção de ataque; a câmera atual já orienta a projeção.
Logs mostram ID/perfil/origem da configuração e projeção da bola para diagnóstico. ID desconhecido, perfil inválido
ou matriz indisponível silencia só radares direcionais; avisos de posse e bola
central própria continuam. Próxima câmera válida recupera orientação. Não promete
isolamento contra erros arbitrários no motor comum. Dados dos perfis não executam Lua.

Bola é loop contínuo com ganho decrescente por distância. Laterais são loops no
ponto mais próximo de cada linha, dentro de8m. alertYourGoalkeeper.wav e
alertOpponentGoalkeeper.wav indicam centros FIXOS dos gols dentro de20m, nunca
acompanham goleiros. Identidade exige sinais nativos válidos de TeamAIInfo;
sem vínculo, somente gols ficam mudos. Ganhos de proximidade crescem suavemente.

Posse vem de ANALYZE/INFO raw+8+2601c, não de MATCH/INFO nem da distância.
Ator0 válido. gotBall.wav e LostBall.wav são toques únicos centrais, ganho0,4.
Troca comum para jogador que já tem bola também pode avisar gotBall. Após passe
próprio, companheiro confirmado toca SOMENTE teamStillWithBall.wav, incluindo
seleção assistida antes/durante/depois da recepção. Bola solta aguarda recebedor
sem LostBall prematuro nem timeout; interceptação confirmada toca LostBall.
Pausa/reentrada/recuperação de dados cria referência silenciosa; mudo consome eventos.

alertTacle.wav repete enquanto houver aproximação experimental: adversário com
posse confirmada, bola até1m de altura e diferença vertical até1m, distânciaXZ
até2m, saindo em2,3m. Não comprova alcance nativo nem garante sucesso do desarme.
Config em FlAccessGameplay.ini: tackle_enabled, tackle_distance,
tackle_exit_distance, tackle_max_ball_height, tackle_volume; lida ao iniciar.

Todos os efeitos usam HRTF/OpenAL no processo do jogo e compartilham política de
volume/mudo do Windows. Não usar reprodutor externo nem multiplicar volume master
no ganho dos efeitos. Não reativar antigos FLAccess_audio/FLAccess_match_registry/
FLAccess_gameplay_live. Reader e controles permanecem independentes.

Bola teve aprovação audível histórica. Nova orientação, laterais, gols, posse e
alerta de desarme continuam pendentes de audição. Testes offline não encerram relatos.
