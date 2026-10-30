# cameraRadars — experimento15, 28/10/2026

## Gameplay experimento15 — cameraRadars e perspectiva, 28/10/2026

Retorno real: orientação ainda incorreta em Dinâmica ampla e Estádio. Usuário
pediu cobertura de todas as câmeras e separação para falha de uma não afetar outras;
pediu pesquisa na internet. NÃO fechar relato real pelos testes abaixo.

Instalado componente interno engine/cameraRadars.lua e10perfis de dados separados
engine/cameraRadars/camera_00.ini..09.ini. Sem entrada adicional no sider.ini.
Perfis incorporados ao gerar Gameplay; editar exige build_gameplay_module.py.
São dados, não Lua executável: texto inválido afeta só seu perfil. Perfis têm
pan_sign/depth_sign/depth_scale, mesma matemática inicial; NÃO calibrados
individualmente por audição. Nomes de menu ainda não vinculados aos IDs. Native
1..6 cria InplayCamera,7..9 VerticalCamera;0 somente perfil de transição. IDs
inesperados não recebem perfil por adivinhação. Erro arbitrário no motor comum
continua podendo afetar outros; não prometer isolamento universal de código.

Causa concreta na base atual: CAMERA/INFO raw+0c guarda matriz de VISÃO/PROJEÇÃO,
não rotação ortonormal. Extrair colunas constantes ignorava perspectiva do jogador
fora do centro, podendo orientar errado. Agora diferença homogênea relativa à
posição atual do jogador, corrigida pela proporção de tela; direção no plano do
campo mantém distância real e altura sonora. Não usa giro do corpo. Referência
esquerda/direita e topo da tela preserva escolha do usuário/analógico. Alvo atrás
da câmera não é invertido por dividir W negativo. Não comprova mesma referência
do áudio original do jogo ou mapeamento nativo de controles em todas as câmeras.

Perfil selecionado por MATCH/ENV raw+48, revalidado na mesma leitura. Fonte tipada
separada de MATCH/INFO e ANALYZE/INFO. Assinaturas FL2026 validadas. Câmera ruim
silencia imediatamente somente loops direcionais; avisos de posse e bola central
com posse própria continuam; câmera seguinte válida recupera. Sem cache de direção
antiga. Cues/posse ANALYZE, tackle experimental, assistência, Reader e DLLs intactos.
WAVs editados pelo usuário e INI instalados conferidos antes/depois, sem mudança.

Pesquisa primária: camera.lua de juce/nesa24 no Sider mostra parâmetros próprios de
câmeras, não oferece adaptador pronto de orientação sonora. Documentação Microsoft
sobre pipeline confirma distinção visão/projeção, perspectiva e espaço homogêneo.
Referências e prova nativa detalhadas em docs/CAMERA-RADARS-2026-10-28.pt-BR.md.

179 contratos câmera passaram:10perfis, oráculo NDC independente, jogador fora do
centro, zoom, alvo atrás, perfil inválido/recuperação e4matrizes de capturas reais
ANTIGAS (27/10), sem inferir rótulo da câmera.104contratos gameplay, registro,
auditoria nativa câmera/posse e2testes pacote passaram. Lifecycle restrito Sider
renderizou WAV/HRTF com falhas de câmera, cues, laterais/gols/tackle, mute/pausa,
assets opcionais ausentes; extração limpa renderizou pacote. Tudo offline,
sem audição real15. Logs tests/camera-radars-validation-2026-10-28.log.

Fonte/Sider Gameplay 2cff87cef721ef7f2ef50253c3b07419af7ebdcd5d2bc9a8f4263f1d284d949d.
Reader preservado a1045efad88d391ad29d8dc29260a65c918e3ebd5be2002d2d30457d8d4be86d.
ZIP local 834ad6b35994aa8e39c1e750ba5d219ef553e4666f799298e60fad4624f3887d,65payloads+manifesto.
Backup local-backups/2026-10-28-before-camera-radars; nada publicado/sincronizado.
Teste seguinte: reabrir jogo, jogar normalmente inicialmente em Dinâmica ampla
ou Estádio e relatar orientação; encerrar turno ao pedir teste, sem monitorar
jogando nem pedir pausa cronometrada. Aprovação histórica da bola preservada;
laterais/gols/orientação/posse/tackle ainda dependem de confirmação audível.

## Referências primárias pesquisadas

- Código original camera.lua, juce/nesa24, repositório pes-modding:
  https://github.com/pes-modding/sider6/blob/master/modules/camera.lua
  Parâmetros separados de câmeras ajudam a organizar perfis. Não é uma solução
  pronta de radar/HRTF nem prova de compatibilidade de endereços com FL2026.
- Microsoft, The Direct3D Transformation Pipeline:
  https://learn.microsoft.com/en-us/windows/win32/dxtecharts/the-direct3d-transformation-pipeline
  Explica visão, projeção, perspectiva, coordenadas homogêneas e viewport.
  A aplicação concreta à matriz encontrada neste jogo é nossa análise nativa.
- Guia oficial de módulos Sider7:
  https://mapote.com/doc/sider/sider7/scripting.html
  Guia consultado declara7.4; não supor que todas as APIs existam na DLL local.
  Nenhuma atualização do Sider ou novo mod de câmera foi instalada.

## Evidência local e fórmula

CameraListener427740:4277c7 chama1eafdf0,4277cc aponta payload+8,
4277d5 copia matriz com a91c20. Factory427bf2 aloca5cbytes;427c15 raw+4.
1eafe00 compõe perspectiva (call1eaf100 em1eafe9e) e look-at
(call1eaf270 em1eaff13), gravando16floats. Logo matriz começa raw+0c.

MATCH/ENV getter41b68c soma4.879a20 resolve referência no manager+28;
879fe6 passa payload ao87a170.87a1b6 recupera argumento;87a47d lê
byte[payload+44], portanto raw+48. Intervalos1..6/7..9 selecionam famílias
Inplay/Vertical. Auditoria tools/verify_camera_radars.py e
 tests/camera-native-audit-2026-10-28.txt preservam instruções atuais.

Para origem O e matriz M, calcular clip C=O*M. Gradientes no chão:
Gx=(Mxz,col0*Cw-Cx*Mxz,col3)*aspect;
Gy=(Mxz,col1*Cw-Cy*Mxz,col3). aspect=norm(col1.xyz)/norm(col0.xyz).
Para deslocamento D entre jogador e alvo: sx=Gx.D, sy=Gy.D.
Normalizar sx/sy para distânciaXZ real; OpenAL recebe (sx normalizado,
diferença de altura,-sy normalizado). Assim direita na tela fica direita sonora;
topo da tela vira frente sonora. W do alvo não divide e não inverte alvo oculto.
A expressão dá diferença de NDC exata em direção para pontos de W positivo;
fora dessa região é uma extensão contínua para orientação, não visibilidade.

Matriz sem dados finitos, origem com W não positivo, projeção degenerada,
ID ausente/desconhecido ou perfil inválido desativa orientação nessa leitura.
Preservar separação de falha da câmera e disponibilidade da posse.
