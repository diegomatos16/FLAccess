# Radar pela tela e investigação da posse

## Gameplay experimento12 — radar pela tela / posse pendente, 28/10/2026

Retorno real experimento11: bola/radar percebidos em lados opostos e movimento
virava referência continuamente; gotBall/LostBall não ouvidos. Usuário esclareceu
assistência Assistido com trocas automáticas. Não mexer nessa assistência; seguir
seleção real inclusive automática. Após exemplo de corpo versus tela, escolheu
TESTAR orientação pela TELA e aceita mudar no futuro. Substitui primeira pessoa
pelo corpo. Não afirmar que referência do áudio ORIGINAL/câmera Jogador foi provada.

Instalado experimento12: usa base horizontal CAMERA com origem no jogador local;
rotação do corpo não governa áudio. Som à esquerda/direita corresponde à tela e
analógico; frente corresponde ao topo da tela no plano horizontal. Mesmo quadro
para bola/laterais/gols. Posse própria central conforme escolha anterior; controles,
assistência, WAVs LIVE, núcleo de volume e Reader preservados. Câmera inválida
silencia e recupera com leitura atual. Sem fallback silencioso para orientação do
corpo. Testes verificam giro da câmera, independência do corpo inclusive ângulo
inválido, troca ator/time, gols, posse simulada, master/pausa e WAVs ausentes.

AVISOS DE POSSE NÃO CORRIGIDOS/COMPROVADOS no jogo. Log real salvo em
local-backups/2026-10-28-radar-feedback/sider-experiment11.log:186 keeper=0,
15 keeper-index-unavailable e14 loose-ball; nenhum possession cue. Seleção troca
pelos atores normalmente. Suíte falsa não comprova origem do campo nativo. Nova
captura limitada compara MATCH/INFO raw+8+2601c com cache MatchInfoRef tipado
world+258/+270 (se disponível), e tail26000..2602c, uma vez por segundo junto da
base horizontal. Sem varredura de heap, escrita no jogo ou inferência de distância.
Essa informação deve distinguir origem/cache/deslocamento na próxima passagem
normal. Não pedir pausa cronometrada; encerrar turno quando pedir teste. Gols
mostraram goal-team-unavailable intermitente no log11; não declarar cobertura deles.

60 contratos/registros, lifecycle offline/HRTF/WAV e cenários sem WAVs opcionais,
comparação nativa instrumentada e2 testes de pacote passaram. Log
 tests/screen-radar-validation-2026-10-28.log. Sem audição da12. Não encerrar relatos.
Reader intacto: A1045EFAD88D391AD29D8DC29260A65C918E3EBD5BE2002D2D30457D8D4BE86D.
Gameplay fonte/Sider 2EDD1A8092970469385A3100D800B2FE9E82D94EC5EC6DD3555EF797ECF5594E. ZIP local b013584d26dc70b7dc8d51f86974daf53aa9aa81b5cc75a0751704e1d2ff43fe.
Backup da11/captura/ZIP em local-backups/2026-10-28-radar-feedback.
Nada publicado/sincronizado; aprovações/pendências de menus preservadas.
