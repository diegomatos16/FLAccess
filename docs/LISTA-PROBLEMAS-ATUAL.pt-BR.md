# Lista consolidada — retorno real de 29/10/2026

## Estado para publicação0.2.0 — 04/11/2026

Usuário autorizou commit, envio e publicação0.2.0 experimental no GitHub.
Confirmou51 ainda lento;52 segue sem confirmação de desempenho. Permanecem
pendentes listas/classificação, agrupamento de jogadores, menu/tooltip principal,
submenu Football Life, cartões/Diário/notícias/data/rolagem da ML, ligas e
participantes, saves/diálogos e relatos de gameplay/áudio sem confirmação.
Novo relato75: opções dos OUTROS módulos do Sider deixaram de ser lidas no FL27.
Correções confirmadas66/71 preservadas. Estados históricos abaixo não certificam
automaticamente o FL27. Resumo vigente em RELEASE-0.2.0.pt-BR.md.

04/11 log51 confirma busca30–32ms/quadro, janelas24–28ms; não resolveu listas.
52 remove invalidação global por foco desconhecido e preserva árvores alheias
na troca de dono/guia; validações e expiração mantidas.449Lua/65Python+1skip/
integração31. Usuário pediu última tentativa antes de GitHub; publicação aguarda
condição/retorno. Painel de jogador ainda tem rótulos/números avulsos no log51.
Ver READER52-ULTIMA-TENTATIVA-LISTAS-2026-11-04.pt-BR.md. Sem fechar relatos.

03/11 retorno50: listas ainda lentas, inclusive busca; painel Salah expõe grupos
de atributos.51 separa listas/grupos em componentes reais, valida cabeçalhos e
cursor sem remontar árvores em quadros estáveis, elimina sondagem de campos
alheios e associa valores apenas apresentados. Usuário escolheu título junto do
primeiro campo de cada grupo. Atributos só na exploração, um campo por passo.
Desempenho/audição51 ainda não confirmados. Não encerrar pendências ML/rolagem.
Ver READER51-LISTAS-GRUPOS-2026-11-03.pt-BR.md.

Retorno46 em02/11: novos relatos61–65 abaixo. Listas com desempenho ruim
(1/6abertos); usuário confirmou atributos apenas na exploração, preservando
nome/situação e classificação automática.47/Aúdio19 instalados, sem audição
nova. Não encerrar relatos por suíte. Ver READER47-AUDIO19-2026-11-02.pt-BR.md.


Retorno FL27 build45: atributos recuperados, confirmados pelo usuário. Nomes de
times estão sendo substituídos por atributos; principal e submenu Football Life
continuam com os relatos anteriores.46 ajusta prioridades, apresentação7 e
publicação única do título. Nenhuma confirmação real46 ainda. Ver relatório
READER46-FL27-2026-11-01.pt-BR.md.


Retorno FL27 —01/11/2026: principal repete nomes/corta tooltips; submenu
Football Life e informações do jogador sem leitura. Instalação verificada44,
igual aos últimos fontes. Ajuste45 instalado, SEM nova confirmação auditiva.
Aprovações históricas não certificam automaticamente FL27. Ver relatório
FL27-BUILD45-2026-11-01.pt-BR.md. Item54 permanece aberto; novos57/58 abaixo.


Retorno real do build44 (31/10/2026): ao perguntar especificamente sobre
classificação, calendário e finanças, usuário respondeu “ta lendo certinho”.
Leitura desses três fluxos confirmada. Isso não confirma todos os cartões da ML,
nem encerra relatos de desempenho, principal ou outras telas. Usuário pediu
somente pacote portátil do build44; investigação seguinte interrompida.


Retorno real do FLAccess0.2.0 build43 (30/10): primeiro item SP Football Life
lido corretamente, confirmado pelo usuário. Liga Master/Rumo ao Estrelato repetem
nome e interrompem tooltip. Classificação fala só time; calendário só meses;
finanças sem agrupamento. Outros cartões abaixo das guias ML ficam silenciosos.
Termo adotado: exploração; I/K e direito sempre um campo completo por passo.
Build44 corrige roteamento/entrega e acrescenta reader_records comum, campos
num_* reais, índice próprio do calendário e pares rótulo/valor. Ainda precisa
de confirmação real. Finanças/cartões desconhecidos não têm cobertura integral
comprovada pelo log atual. Ver READER-DEV44-2026-10-30.pt-BR.md.


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

4. **LEITURA DO PRIMEIRO ITEM CORRIGIDA — confirmação real no FLAccess0.2.0 build43.** Usuário diz que primeiro SP Football Life está lendo corretamente. Preservar caminho comum; não inferir aprovação geral de desempenho1/6.

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

45. **IMPLEMENTADO, cobertura parcial.** I/K e analógico DIREITO cima/baixo usam o mesmo buffer nos componentes reconhecidos. Um campo completo por passo. Repetir removido48: J primeiro, L sem ação; J/L para notícias ainda pendente. Grupo nativo reconhecido acompanha o primeiro campo ao entrar nele; não há cobertura integral de todas as telas.

46. **REPRODUZIDO após37; ajuste38 instalado.** Boas-vindas ML inclui Ajuda/Avançar/menu ao fundo na revisão.38prioriza corpo apresentado e exclui controles/legendas. Perguntas/mensagens sem respostas no buffer; confirmação real pendente.

47. **PARCIAL confirmado39; ajuste40.** SAPI indevido aprovado50; só algumas mensagens lidas.40tenta fragmentos UTF8 limitados no mesmo backend em error13. Audição necessária; não afirmar todas corrigidas.

48. **IMPLEMENTADO38, cobertura parcial.** Situação/lista de jogadores: revisão só do jogador selecionado e campos vinculados à linha. Painel detalhado sem associação nativa comprovada continua pendente; não afirmar todos os atributos cobertos.

49. **IMPLEMENTADO38, aguardando confirmação.** “Carregando tela” após3segundos, uma vez por carregamento nativo contínuo. Escolha do usuário confirmada. Transições rápidas silenciosas; bloqueio completo da thread de render limita aviso.

50. **CORRIGIDO — confirmado pelo usuário após39.** Mensagens deixaram de usar SAPI indevidamente. Preservar ausência de alternância/retries por frame. Conteúdo parcial continua47.

51. **CORRIGIDO NOS FLUXOS TESTADOS — confirmação real do build44 em31/10/2026.** Classificação e calendário: usuário respondeu “ta lendo certinho” à pergunta específica sobre as telas. Preservar agrupamento automático e exploração de um campo completo por passo; outras variantes não percorridas não ficam aprovadas por inferência.

52. **IDENTIFICADO por componente; ajuste39.** Item silencioso abaixo das guias ML inclui tabela leagueRank em c_newsChoice_2. Anunciar Classificação quando esse componente é o selecionado; outros componentes não recebem esse nome por suposição. Validação real pendente.

53. **REPRODUZIDO39; ajuste40.** Instruções ofensivas sem tooltips.40reconhece HelpBox nativo/descrições atuais sem rótulo de áudio/cadastro por tela. Canal comum, partes atuais, toggle e validação. Confirmar no jogo.

## Aprovações históricas preservadas

Opções iniciais do plano de jogo; nomes em Editar posição; configurações de
câmera/estádio; configurações Champions; edição do nome do treinador; valores
ML; confirmação da segunda etapa ML; recuperação de leitura anteriormente
aprovada; instruções automáticas; retirada de tipos sintéticos; bola audível.
Não usar esta lista para reabrir essas aprovações. Questão Alt+F4 retirada.
Tempo/placar falados continuam trabalho futuro, não falha de recurso já entregue.

54. **REPRODUZIDO no build43; ajuste44.** Liga Master e Rumo ao Estrelato repetem nome e cortam tooltip. Roteador único no principal e entrega preservada durante perda temporária de foco; aguardando audição.

55. **LEITURA CONFIRMADA NO FLUXO TESTADO — build44 em31/10/2026.** Finanças incluída na pergunta específica; usuário respondeu “ta lendo certinho”. Preservar vínculo nativo rótulo/valor. Não inferir cobertura de todos os relatórios financeiros.

56. **REPRODUZIDO no build43; cobertura44 parcial.** Alguns cartões sob guias da ML não são lidos; Classificação é lida corretamente segundo usuário. Nome itemName apresentado pode ser lido no cartão selecionado mesmo sem foco próprio. Cartões restantes não identificados ficam abertos.

57. **REPRODUZIDO NO RELATO FL27; ajuste45.** Submenu após Football Life sem leitura. Travessia SWF guardada adicionada; confirmar leitura automática e exploração.

58. **REPRODUZIDO NO RELATO FL27; ajuste45.** Informações do jogador sem leitura. Corrigida descoberta de textos sob carregadores SWF; não declarar todos os atributos cobertos antes do teste real.

59. **RELATO ABERTO — orientação/antecedência do aviso de desarme, FL27.** Usuário ouve alerta pela esquerda; ao mover, som muda de lado e há pouco tempo para agir. Confirmou que o adversário está com a bola. Atual alerta indica proximidade da bola, não intenção ou resultado de desarme. Câmera Jogador ID8 usa corpo; não declarar solução sem retorno. Raio/semântica ainda sem nova decisão.

60. **REPRODUZIDO45; ajuste46 aguardando audição.** Na escolha de time, ZG/AT/MC interrompem/substituem nome do clube. Lista nativa precede registros auxiliares; entrega atual invalida pacote anterior de atributos. Preservar informações de jogador recuperadas e aprovação de atributos45.

61. **RELATO ABERTO — endereço nas configurações de áudio.**47filtra endereços na fala de painéis Sider; origem exata não comprovada na captura46. Confirmar resultado.

62. **REPRODUZIDO46 — Editar posição repetido fora do plano após substituição.**47bloqueia foco/página antiga quando relógio nativo indica partida ativa; confirmar.

63. **REPRODUZIDO46 — sons param ao retomar.** Log perde ligação com áudio do jogo.19reconhece sessão nativa recriada por classe estável, repara target expirado e retoma loops parados. ABI preservada; confirmar audição.

64. **REPRODUZIDO46 — slots ML.**47agrupa número exibido thumbailNumber e conteúdo da linha tipada SaveDataSelect; não inventar índice por posição na árvore. Confirmar.

65. **REPRODUZIDO46 — sobrescrita sem pergunta automática.**47lê corpo apresentado do DialogAgreement e impede título Salvar de substituir a pergunta. Respostas nativas preservadas; confirmar.

66. **CORRIGIDO — confirmação do usuário no build48 em03/11/2026.** Configurações sem sufixo hexadecimal. Preservar limpeza de cor/reset.

67. **PENDÊNCIA DA0.2.0 — lentidão grave nas listas.** Ligas/clubes, jogadores/busca e classificação deixam o jogo pesado. Usuário confirmou51 ainda lento; log51 tem trechos30–32ms/quadro. Ajustes49–52 reduziram sondagens e invalidações em testes, mas não encerram o relato. Desempenho52 sem confirmação real. Atributos somente na exploração.

68. **RELATO ABERTO — Diário no cartão ML silencioso.** Tela interna lê Diário; vínculo do cartão ainda não comprovado.

69. **PLANEJADO — notícias e data ML.** Data automática ao entrar e na exploração, conforme resposta do usuário. Proposta J/L e direito horizontal para notícia anterior/próxima, I/K e direito vertical para campos. Usuário removeu comando de repetir:48remove L/repeat; navegação horizontal de notícias ainda pendente de dados nativos.

70. **RELATO ABERTO — classificação só alcança cinco times.**48reordena time/posição/pontos/saldo antes das demais estatísticas. Alcance/rolagem e atualização parcial de registros continuam em investigação; não escrever cursor ou inventar times.

71. **CORRIGIDO — confirmação do usuário no build48 em03/11/2026.** Itens Sim/Não do diálogo são lidos. Preservar autoridade pelo cursor do DialogAgreement, sem exigir dono SWF igual à pergunta.

72. **PLANEJADO — dados de liga/participantes agrupados só na exploração.** Campos ainda por comprovar, sem ampliar coleta automática.

73. **REPRODUZIDO49 — listas/classificação lentas; cinco times e data ML.**50reusa estrutura validando ligações/cursor atuais, resolve índice do grupo da classificação e aguarda assinatura estável em outro quadro para publicação automática. Adiciona Date nativa da carreira ao entrar e na exploração. Direito coleta uma vez/passo, I inicial vai ao último campo.441Lua/43contratosFL27/integração29 passam; NÃO fechar67/70 ou parte data69 sem retorno real. J/L notícias/Diário/liga-participantes seguem pendentes.

74. **PENDÊNCIA DA0.2.0 — agrupamento dos dados do jogador.** Painel da busca/Salah e outros grupos podem ler altura, peso, força e demais rótulos/valores separadamente, além de conteúdo indevido.51 separou reader_groups de reader_lists e usa relações nativas comuns, mas log51 ainda mostra números/rótulos avulsos. Não afirmar correção geral nem cobertura tela a tela. Um campo por passo; título real junto do primeiro campo de cada grupo.

75. **NOVO RELATO ABERTO — opções de outros módulos do Sider sem leitura no FL27.** Usuário informou em04/11/2026 que o leitor deixou de anunciar as outras opções desses módulos. Registrar regressão de compatibilidade/integração; causa, módulos afetados e extensão não foram comprovados. Incluído nas pendências públicas0.2.0; sem tentativa de correção nesta publicação.
