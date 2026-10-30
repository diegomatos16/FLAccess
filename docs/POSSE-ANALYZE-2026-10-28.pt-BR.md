# Origem do jogador com posse

## Gameplay experimento13 — origem da posse corrigida ANÁLISE, 28/10/2026

Usuário pediu investigar jogador0 ANTES de nova passagem. Encontrada causa estática
concreta: 2601c é campo de AnalyzeInfo, não MatchInfo. MATCH/INFO payload tem apenas
2378hex bytes (factory4e0810, size4e08bb). Código antigo lia fora desse objeto;
zeros/255/valores alheios vistos no log não provavam posse real. Retirar conclusões
anteriores que diziam MATCH/INFO comprovado para o campo; auditoria anterior provou
somente cabeçalho, confundiu identidade do objeto produtor. Não banir ator0.

Rota comprovada: produtor457259 recebe r13=[context+508]. Constructor4563e5 coloca
AnalyzeInfoRef emcontext+4e8; vtable259d590 em4563fc resolve grupoANALYZE, propertyINFO.
4582e1 chama getter4589a0 desse mesmo Ref; getter4589ec faz raw+8 e4589f0 guarda
cache+20, que corresponde exatamente acontext+508. Alocação4636e2 éeae28hex,
payload emraw+8, portanto campo2601c cabe. ANALYZE/INFO raw+8+2601c agora é única
fonte de posse, revalidando entrada. Campo desconhecido/missing nunca vira perda.
Módulo13 instalado e ZIP atualizado. Diagnóstico inseguro MATCHtail removido;
log agora informa keeper-source=ANALYZE/INFO. Nenhuma leitura grande/heapscan,
chamada nativa ou escrita no jogo. Bola central e gotBall/LostBall passam a usar
esta fonte. Seleção automática/Assistido segue observada sem mexer na assistência.
Orientação pela TELA da12 preservada conforme aprovação; nada de voltar ao corpo.

Auditoria tools/verify_possession_source.py e evidência
 tests/possession-source-native-2026-10-28.txt. Fixtures distinguem MATCH pequeno,
zero alheio no endereço errado e ANALYZE real simulado. Teste rejeita qualquer
leitura no endereço errado e passa com MATCH indisponível/ANALYZE válido. Reproduz
regressão anterior; testa ator0 válido, troca de jogador/ganho/perda, unknown/pausa,
mute, WAVs ausentes.60 contratos/registro e HRTF/WAV offline,2 testes de pacote e
extração limpa passaram. Log tests/analyze-possession-validation-2026-10-28.log.
Isso prova correção do vínculo e testes internos; sem audição da13 no jogo. Manter
relatos de sons/centro/posse abertos até retorno real. Não pedir outra captura para
descobrir essa causa: já descoberta/corrigida antes do teste pedido pelo usuário.

Reader e WAVs LIVE intocados. Readerhash
A1045EFAD88D391AD29D8DC29260A65C918E3EBD5BE2002D2D30457D8D4BE86D.
Gameplay fonte/instalada 86C6404EA2EF4F6851FF7EDCD9EB65E7D9DBA4E59F384ECDED6AD8A2493C96EA. ZIP local 7f9b5bd0f317e6f822807c600ed6a42b613211d8c718e633ab158e299a0b34c3.
Backup12 emlocal-backups/2026-10-28-before-analyze-possession; captura11 preservada.
Nada publicado/sincronizado. Reabrir jogo para teste normal, sem pausa cronometrada;
ao pedir teste, encerrar turno e aguardar usuário. Restante das pendências preservado.
