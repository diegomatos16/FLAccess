# Lista consolidada — retorno real de 29/10/2026

Retorno real da dev41 (30/10): primeiro item congela e atrasa; países continuam
falhando; classificação E calendário sem leitura. Calendário passa a reproduzido.
Dev42 instalada: conversão de ponteiros cdata corrigida; publicador inicial
unificado às outras opções; país pelo ID filtrado e base nativa. Testes passaram,
mas1/6/4/25/51 continuam abertos até confirmação real. Ver relatório dev42.


Revisão dev41 (30/10): usuário ainda percebe lentidão e problemas sem resolver.
Nenhuma nova aprovação individual. Refatoração Lua instalada: fila única após
foco, até2tentativas de fala/quadro e correção de cancelamento/entrega de países,
tooltips e fragmentos. Ver READER-DEV41-2026-10-30.pt-BR.md. Estados anteriores
abaixo continuam válidos onde não atualizados pelo retorno41; nenhum relato encerrado
por testes internos.50SAPI preservado,42sem intervenção e15futuro.


Numeração1–39 preservada da lista original, diferente da matriz antiga de19
itens. Novos relatos40–44 adicionados em29/10. Aprovações reais até a dev32
registradas abaixo. Testes internos não substituem essas confirmações.
“Não verificado” significa não testado extensivamente ou ainda não testado;
não é nova reprodução nem revogação de aprovações históricas.

1. **ABERTO — lentidão reproduzida após41; ajuste42 instalado.** Captura41com1686abortos por cdata;42corrige conversão. Não afirmar navegação otimizada definitivamente sem retorno real.

2. **CORRIGIDO — confirmado pelo usuário.** Atraso artificial dos tooltips.

3. **CORRIGIDO — confirmado pelo usuário.** Versão inicial ausente.

4. **REPRODUZIDO após41; ajuste42 instalado.** Primeiro Football Life congela e demora para ler. Retirado publicador especial; mesmo par text_item/text_value e publicador das outras opções. Corrigido aborto de memória. Confirmar nome/tooltip/fluidez no jogo.

5. **REGRESSÃO reproduzida após37; ajuste38 instalado.** Digital Awakening foi anunciado ao avançar na ML. Título passivo sem dono não pode virar título pendente; music/artist exigem lista nativa de trilha sonora. Aprovação histórica no principal preservada, novo relato aberto até audição.

6. **ABERTO — estabilidade/desempenho.**39melhorou segundo usuário;40reduz trabalho e invalidações por tarefas auxiliares. Não declarar fim das travadas/silêncios.

7. **CORRIGIDO — confirmado pelo usuário.** Valores dos controles de volume ausentes.

8. **CORRIGIDO — confirmado pelo usuário na dev30.** Título Idioma do comentário ausente.

9. **CORRIGIDO — confirmado pelo usuário.** Guias do treinamento silenciosas.

10. **CORRIGIDO — confirmado pelo usuário.** Guia do treinamento depois do exercício.

11. **CORRIGIDO — confirmado pelo usuário na dev30.** Repetição do jogador parado no plano de jogo.

12. **CORRIGIDO — confirmado pelo usuário.** Situação titular/reserva/não relacionado incorreta ou ausente.

13. **CORRIGIDO — confirmado pelo usuário na dev30.** Repetição da situação fora da entrada/troca de grupo.

14. **POSIÇÃO NO CAMPO CORRETA — confirmado pelo usuário após dev33.** Não anunciar principal inferida. Estilos continuam ausentes; por decisão do usuário, ficam junto do trabalho futuro15.

15. **TRABALHO FUTURO — estilos de jogo e posições reais.** Investigar ausência dos estilos e origem independente das posições originais/secundárias. Completas/parciais incorretas continuam retiradas. Não reabrir isso como correção ativa nesta rodada.

16. **CORRIGIDO — confirmado pelo usuário na dev30.** Prefixo Formação antes do valor numérico.

17. **CORRIGIDO — confirmado pelo usuário na dev30.** Título automático Informações do jogador ao abrir Y/Triângulo.

18. **CORRIGIDO — confirmado pelo usuário na dev30.** Ajuda, Voltar, título ou outras legendas dentro da revisão do jogador.

19. **CORRIGIDO — confirmado pelo usuário.** Altura e peso separados dos respectivos valores/unidades.

20. **CORRIGIDO — confirmado pelo usuário.** Atributos sem rótulo e valor agrupados por passo.

21. **CORRIGIDO — confirmado pelo usuário.** Revisão por I/K e analógico direito cima/baixo.

22. **CORRIGIDO — confirmado pelo usuário.** Pausa anunciando aviso de início de partida em vez de Menu de pausa.

23. **CORRIGIDO — confirmado pelo usuário na dev30.** Opções silenciosas da pausa: somente cerca de duas são lidas.

24. **CORRIGIDO — confirmado pelo usuário na dev30.** Revisão da escolha de clube inclui clubes indevidos em vez de clube/elenco atuais.

25. **REPRODUZIDO após41; ajuste42 instalado.** Países ainda falham. Override nativo usa IDs de vetor filtrado, não nomes dos registros genéricos50hex.42segue ID selecionado e nome exato na base do jogo, com revalidação; confirmação real pendente.

26. **CORRIGIDO — confirmado pelo usuário na dev30.** Avançar/Confirmar ao retornar da edição do nome do treinador.

27. **NÃO VERIFICADO neste retorno.** Pular sem identificar o botão/tecla apresentado.

28. **RELATO ATUAL — comando de avançar da primeira tela ML silencioso (possivelmente Próximo).**37acrescenta leitura das legendas reais da barra de comandos vinculada ao painel de mensagem. Não inventa nome de botão; esta tela ainda aguarda confirmação. Demais partes da introdução sem verificação extensiva.

29. **CORRIGIDO — confirmado pelo usuário após dev33.** Entrada da seleção de liga/clube legível.

30. **CORRIGIDO — confirmado pelo usuário na dev35.** Troca automática por LT/RT anuncia Usuário1/2/3 e lado corretamente. Preservar a correção ao reverter a intervenção no cursor.

31. **NÃO VERIFICADO neste retorno.** Orientação incorreta do radar em Dinâmica ampla e Estádio.

32. **NÃO VERIFICADO neste retorno.** Calibração audível das outras câmeras sem confirmação.

33. **NÃO VERIFICADO neste retorno.** Sons das laterais não ouvidos.

34. **NÃO VERIFICADO neste retorno.** Sons dos gols próprio/adversário sem confirmação.

35. **NÃO VERIFICADO neste retorno.** Centralização da bola na posse própria sem confirmação.

36. **NÃO VERIFICADO neste retorno.** Avisos de ganho/perda de posse sem confirmação.

37. **NÃO VERIFICADO neste retorno.** Aviso de continuidade de posse do time após passe/troca automática sem confirmação.

38. **NÃO VERIFICADO neste retorno.** Aviso repetido de oportunidade de desarme experimental sem confirmação.

39. **NÃO VERIFICADO neste retorno.** Efeitos acompanhando volume/mudo do jogo sem confirmação no uso real.

40. **CORRIGIDO — confirmado pelo usuário na dev32.** Substituição funciona normalmente; nomes acompanham os jogadores corretos. Preservar o vínculo ao alvo real, sem voltar à suposição do painel primário.

41. **CORRIGIDO — confirmado pelo usuário na dev32.** Configurações de ajuda funcionando. Aprovação cobre esta passagem; preservar proteção de cópia e nomes/valores dos seletores.

42. **INTERVENÇÃO REVERTIDA por solicitação do usuário na dev36.** Usuário relatou congelamento ao descer após35. Removido todo fechamento automático do cartão description_offline e a escrita de resultado nativo. Manter comportamento original do jogo; não retomar alterações nessa navegação sem novo pedido. Não declarar travamento corrigido.

43. **CORRIGIDO — confirmado pelo usuário na dev31.** Trilha sonora anuncia faixas/artista/estado. Preservar.

45. **IMPLEMENTADO37, aguardando confirmação.** I/K e analógico DIREITO cima/baixo usam o mesmo buffer nos componentes reconhecidos. Jprimeiro/Lrepete preservados. Novo escopo de jogador selecionado48.

46. **REPRODUZIDO após37; ajuste38 instalado.** Boas-vindas ML inclui Ajuda/Avançar/menu ao fundo na revisão.38prioriza corpo apresentado e exclui controles/legendas. Perguntas/mensagens sem respostas no buffer; confirmação real pendente.

47. **PARCIAL confirmado39; ajuste40.** SAPI indevido aprovado50; só algumas mensagens lidas.40tenta fragmentos UTF8 limitados no mesmo backend em error13. Audição necessária; não afirmar todas corrigidas.

48. **IMPLEMENTADO38, cobertura parcial.** Situação/lista de jogadores: revisão só do jogador selecionado e campos vinculados à linha. Painel detalhado sem associação nativa comprovada continua pendente; não afirmar todos os atributos cobertos.

49. **IMPLEMENTADO38, aguardando confirmação.** “Carregando tela” após3segundos, uma vez por carregamento nativo contínuo. Escolha do usuário confirmada. Transições rápidas silenciosas; bloqueio completo da thread de render limita aviso.

50. **CORRIGIDO — confirmado pelo usuário após39.** Mensagens deixaram de usar SAPI indevidamente. Preservar ausência de alternância/retries por frame. Conteúdo parcial continua47.

51. **CLASSIFICAÇÃO E CALENDÁRIO REPRODUZIDOS após41; ajuste42 instalado.** Sem leitura nas duas telas. Captura mostra abortos de menu_read nesses fluxos; corrigida normalização cdata no caminho comum. Agrupamento/revisão por registro preservados e exercitados com RPM/renderizadores reais no processo de teste; audição pendente.

52. **IDENTIFICADO por componente; ajuste39.** Item silencioso abaixo das guias ML inclui tabela leagueRank em c_newsChoice_2. Anunciar Classificação quando esse componente é o selecionado; outros componentes não recebem esse nome por suposição. Validação real pendente.

53. **REPRODUZIDO39; ajuste40.** Instruções ofensivas sem tooltips.40reconhece HelpBox nativo/descrições atuais sem rótulo de áudio/cadastro por tela. Canal comum, partes atuais, toggle e validação. Confirmar no jogo.

## Aprovações históricas preservadas

Opções iniciais do plano de jogo; nomes em Editar posição; configurações de
câmera/estádio; configurações Champions; edição do nome do treinador; valores
ML; confirmação da segunda etapa ML; recuperação de leitura anteriormente
aprovada; instruções automáticas; retirada de tipos sintéticos; bola audível.
Não usar esta lista para reabrir essas aprovações. Questão Alt+F4 retirada.
Tempo/placar falados continuam trabalho futuro, não falha de recurso já entregue.
