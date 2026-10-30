# Perfis de câmera — experimento16

## Gameplay experimento16 — perfis instalados e famílias nativas, 28/10/2026

Usuário autorizou implementar o possível após estudo de mods. Instalado16, sem
importar motores externos ou mudar controles. Fechado vínculo estático de família:
manager lê ID MATCH/ENV, construtor Inplay guarda tipoobjeto+8, vtable2609c48 chama
87f280; callback recebe MESMO objeto e despacha IDs3/6 para8a57f0, outros para
8a1a70. Consumidores e assinaturas dos módulos fornecidos pelos autores confirmam
ID2fan_view,3broadcast,5dynamic_wide(Dinâmica ampla),6stadium(Estádio). Demais
rótulos continuam sem associação. Isso identifica família; NÃO comprova direção
do analógico nem calibração audível. Audit tools/verify_camera_radars.py ampliada
com produtor, vtable e consumidor; evidência tests/camera-native-audit-2026-10-28.txt.

cameraRadars0.1.1 lê cada engine/cameraRadars/camera_XX.ini INSTALADO ao iniciar.
Agora calibrar pan_sign/depth_sign/depth_scale não exige recompilar. Arquivo
inexistente usa padrão incorporado; presente vazio/ruim/IDerrado/maior4096bytes
isola somente perfil, sem disfarçar por fallback. Aceita BOMUTF8 de editorWindows.
Reabrir jogo para reler; sem hotkey ou polling de arquivos durante jogo. Logs
informam origem embedded/installed, ID/família, parâmetros e projeção da bola.
Instalação preserva INIs de câmeras personalizados; atualiza nomes somente em
cópias idênticas aos padrões15. WAVs/Reader/DLLs/sider.ini/INIgeral preservados.

Matemática da15 preservada: projeção perspectiva relativa ao jogador, orientação
pela tela escolhida, bola central com posse própria. NÃO adicionada transformação
suposta dos controles, giro pelo corpo ou detector heurístico da seleção.
Sem ajuste automático de sinais por ataque. Portanto não alegar nova correção
audível de orientação nesta16; permite identificar e calibrar separadamente.
Ainda falta comprovar vínculo da direção dos comandos nas diferentes câmeras.

191contratos câmera e104gameplay, registro, auditorias câmera/posse,2pacote passaram.
Render lifecycleWAV/HRTF cobre isolamento/cues/mute/pausa/loops e assets opcionais
ausentes; bundle e extração limpa leram perfis reais. Logs
 tests/camera-profiles16-validation-2026-10-28.log. Sem audição16; relatos reais e
aprovação histórica da bola preservados. Controles/Reader/menu pendentes intactos.

Gameplay fonte/Sider cc50e7cf78e29471003eef53478229af1a0da89e667b3e0d5339fff95df950c9.
Reader a1045efad88d391ad29d8dc29260a65c918e3ebd5be2002d2d30457d8d4be86d.
ZIP local db5427b4b180aeaf3acaa413b8cb6c17132359d560bcdba55c4cdefca401373c,65payloads+manifesto.
Backup local-backups/2026-10-28-before-camera-profiles16. Nada publicado/sincronizado.
Teste seguinte focado nas duas câmeras já relatadas: reabrir, jogar normalmente,
relatar câmera e se radar orienta movimento até bola ou passa de lado cedo demais.
Encerrar turno ao pedir teste; sem monitorar jogando nem pedir pausa cronometrada.
