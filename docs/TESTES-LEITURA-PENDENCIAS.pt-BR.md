# Testes de leitura e pendências

## Publicação 0.1.8 — 26/10/2026

Usuário autorizou publicar a base atual como 0.1.8, preservando 0.1.7.
Somente identificação alterada em relação à dev 25; lógica preservada.
321 Lua por cópia/40 Python (incluindo dois testes de empacotamento), sandbox
Sider/15 assinaturas passaram. DLL Sider testada e Prism incluídos no repositório
+ instalador; política permanente em docs/PUBLICACAO.pt-BR.md. Não publicar
somente Lua. Preservar aprovações reais dev 24; revisão/situação da dev 25
sem confirmação audível, item 16 aberto. Ver docs/RELEASE-0.1.8.pt-BR.md.

## Entrega dev 25 — revisão do jogador, 25/10/2026

Usuário escolheu secundárias completas e parciais com distinção. Implementado:
primeiro K número/nome; depois principal, secundárias existentes e função no
campo ou Não está no campo. I volta; analógico direito baixo/cima equivalente.
Titular/reserva/não relacionado somente na navegação automática entre jogadores.
Leitor do painel usa descritor nativo slot/lado/ID; elimina dependência do cache
que estava vazio na captura real dev 24. Limite padrão de relacionados lido
do jogo; regras de competição não resolvidas exigem retorno do hook e seguem
desconhecidas sem essa prova. Item 16 permanece aberto, sem audição da dev 25.

321 Lua por cópia/38 Python/sandbox/15 assinaturas passaram; fonte/Sider iguais.
Casos internos incluem campos distintos, secundárias completas/parciais,
controle, troca/reentrada, nome igual com ID diferente e descarte de fala antiga.
Não são prova de funcionamento audível. Opções do plano de jogo e nomes em
Editar posição seguem aprovados pelo usuário na dev 24; demais aprovações
preservadas. Relatório REVISAO-JOGADOR-DEV25-2026-10-25.pt-BR.md. Captura
real dev 24 preservada; nova sessão armada com PLAYER_DATA. Este estado
substitui o alinhamento anterior registrado abaixo.

## Decisão sobre a fala da situação do elenco — 25/10/2026

Usuário esclareceu: titular, reserva e não relacionado são falados somente
durante a navegação entre jogadores, acompanhando a identificação do jogador.
Não incluir essa situação como etapa nem repeti-la na revisão por I/K ou pelo
analógico direito. Revisão continua destinada a número/nome, posição principal,
secundárias existentes e posição atual no campo ou Não está no campo.
Essa última frase descreve a presença no campo e permanece na revisão; não é
substituída por reserva/não relacionado. Decisão registrada; código ainda dev 24.

## Confirmação audível dev 24 e revisão do jogador em alinhamento — 25/10/2026

Usuário confirmou funcionando as duas correções: leitura das opções na primeira
tela do plano de jogo e nomes dos jogadores ao entrar em Editar posição.
Essas duas regressões estão aprovadas por audição real. Situação titular,
reserva ou não relacionado continua ausente segundo o usuário; item 16 aberto.
Preservar as demais aprovações e pendências.

Novo comportamento solicitado para esclarecer antes de implementar: revisar
informações do jogador em foco, uma informação por vez, com K avançando e I
voltando; analógico direito para baixo/cima deve equivaler a K/I nesse contexto.
Exemplo informado: primeiro K repete número e nome (3 Bolívar); próximo lê
posição principal; depois posição no campo. Incluir posições secundárias se
existirem. Quem não estiver no campo deve receber a frase Não está no campo.
Posição principal e posição atual no campo são dados distintos; não inferir
uma da outra. Dados ausentes não autorizam inventar posição ou situação.

Situação titular/reserva/não relacionado foi posteriormente definida: somente
na navegação entre jogadores, fora da sequência de revisão. Ordem exata das
secundárias ainda não recebeu alinhamento específico. Nenhuma alteração de código
ou nova build nesta atualização; instalada permanece dev 24.

## Estado atual — plano de jogo e nomes / dev 24 instalada, 25/10/2026

Usuário relata opções silenciosas na entrada do plano de jogo e nenhum nome
em Editar posição. Confirmou navegação pelo controle. Dev 24 instalada: cursor
sem texto pode usar legenda única do próprio grupo; família nativa SelectBase
vincula o nome no painel ParameterPlayerInfo por lado/Task pai/cursor real.
Nomes independem de cache de atributos ou prova de situação. Demais campos do
painel não disputam seleção; identidade e entrega revalidam cursor/vínculo.
Sem condições por nome de tela, novo hook ou restauração de ordem presumida.

313 Lua por cópia/35 Python/sandbox/15 assinaturas passaram, 175 locais.
Fonte/Sider iguais, SHA256
61EF527EBC25F9178619C60321F6A0B8DDA8770A48687EEB1303A4BF4707AF0B.
Log tests/dev24-cursor-caption-suite.log; relatório
 docs/PLANO-ELENCO-DEV24-2026-10-25.pt-BR.md.
Sem audição dev 24: os dois relatos continuam abertos; situação do item 16
não recebeu aprovação nova. Demais aprovações/pendências preservadas.

Captura dev 23 encontrada cobria apenas título; preservada em
 tests/capture-dev23-components.log. Trace de 23/10 e sider de 25/10 preservados
separadamente; não combinar endereços entre sessões. Padrão confrontado com
captura dev 21 existente e contratos do executável, sem usar código histórico.
Captura rearmada com CAPTION_SELECTION para vínculo específico. Não pedir nova
passagem ampla nem apresentar testes simulados como prova de audição no jogo.

## Estado atual — elencos / dev 23 instalada, 22/10/2026

Usuário pediu suporte aos elencos e relatou situação titular/reserva/não
relacionado ausente. Captura real encontrada build 21 de 20/10, preservada em
tests/capture-dev21-components.log e sider correspondente; não era mais build 18.
Dev 22 preparada nesta rodada: raiz de apresentação para limite, travessia de
árvore sem duplicatas/até 2048, linha composta de jogador e revisão I/K/J/L
indexada, nomes iguais separados e validação de fala antiga. Sucedida pela dev 23.

Dev 23 instalada: painel de informação separado liga ID validado do jogador ao
slot/modelo atual, mesmo lado e Task pai; exige acordo com cartão apresentado
e ordem do elenco. Situação usa slot e limite real da regra; desconhecido não
vira palpite. Decisão comum/adaptadores descartam vínculo antigo e permitem
anunciar mesmo jogador após mudar situação. Sem novos hooks nem condições por
nome de tela. Relatório docs/ELENCOS-DEV23-2026-10-22.pt-BR.md.

309 Lua por cópia/34 Python/sandbox 120 frames/15 assinaturas passaram, 175
locais; fonte/Sider iguais, SHA256
DBFAD153A2821A00B4FA59354F961A3F848F322D6FA078BA6C62D9169F1F8795.
Log tests/dev23-rosters-suite.log. Sem confirmação audível dev 22/23: item 16
continua aberto; demais aprovações e matriz preservadas. Testes simulados do
modelo e contratos do executável não comprovam descoberta/audição no jogo.
Captura de uma sessão rearmada com SLOT/ID e PLAYER_PANEL para vínculo específico;
ler logs no próximo uso, sem pedir outra passagem ampla. Trabalho desta rodada local.

## Publicação 0.1.7 — 21/10/2026

Base dev 21 publicada por autorização do usuário. Nenhuma pendência adicional
foi encerrada por essa publicação. Consulte RELEASE-0.1.7.pt-BR.md.

## Entrega dev 21 — 19/10/2026

Sem nova captura de jogo desde a dev 20. Reprodução interna comprovou fala adiada
com valor antigo após alteração. Corrigido o transporte do resultado comum durante
a espera, com validação antes de liberar. Relatório FALA-ADIADA-DEV21-2026-10-19.pt-BR.md.
295 Lua por cópia/33 Python/sandbox/15 assinaturas passaram; fonte/Sider iguais.
Nenhum relato real encerrado. Estados, aprovações e matriz da dev 20 preservados.
Captura continua armed; não confundir o log build 18 com uma sessão da dev 21.


## Entrega dev 20 — 19/10/2026

Instalada após autorização da decisão comum. Matriz de TODOS os pendentes,
mecanismos e limites: DECISAO-COMUM-DEV20-2026-10-19.pt-BR.md. 291 Lua por cópia,
33 Python, sandbox/15 assinaturas passaram. Fonte/Sider idênticos, 175 locais.
Dez pacotes da captura dev 18 validam composição; não provam descoberta/audição.
Captura rearmada com resultado completo, grupo/coluna e parentesco de janela.
Sem audição dev 20: nenhum pendente real encerrado. Preservar aprovações abaixo.
Título inicial, países e introdução/home ML ainda sem vínculos completos
comprovados; demais mecanismos novos aguardam uso real. Não solicitar ampla
repetição de tudo nem anunciar resolução pela suíte verde.


## Pesquisa de referência — 19/10/2026

Comparação de código de quatro mods e plano comum dos pendentes em
REFERENCIAS-MODS-E-ARQUITETURA-2026-10-19.pt-BR.md. Sem alteração de runtime,
instalação ou aprovação de relato. Prioridade: decisão coerente por componente
e contexto, composição de nome/valor/estado e retorno; manter revisão plana.


## Retorno real dev 18 — prevalece sobre históricos abaixo

- 4 Champions: configurações aprovadas pelo usuário.
- 12 refinamento do perfil: conteúdo do nome do treinador aprovado.
- 2 câmera e estádio: preservar aprovações.
- 19 novo: seleção de lado anuncia Usuário X sem Em casa/Neutro/Fora. Aberto.
- Demais pendentes mantidos; nenhuma aprovação inferida pela suíte.

Investigação e limites: REGRESSOES-E-CONTEXTO-2026-10-19.pt-BR.md.
Fonte candidata dev 19 com 271 Lua/30 Python/sandbox/15 assinaturas aprovados,
NÃO instalada. Instalada permanece dev 18. Item 19 ainda não foi corrigido;
não reativar nomes por ordem de descoberta. Marcador consumed, captura preservada.


## Investigação de 3, 14 e 16 / dev 18 — 19/10/2026

Dev 18 instalada. Guias seguem registro/índice nativo, Pular recebe vínculo da
barra comum e símbolos reais do renderizador, elenco segue cartão/slot, rolagem
e limite real da regra. Detalhes: GUIAS-COMANDOS-ELENCO-2026-10-19.pt-BR.md.
269 Lua por cópia/28 Python, sandbox e 15 assinaturas passaram. Sem audição:
3, 14 e 16 continuam pendentes de confirmação real; implementado não significa
resolvido no jogo. Preservar todos os estados reais abaixo, sem reabrir aprovados.
Captura armada com PAGE/COMMAND/ROSTER/SLOT para os vínculos específicos.
Validação: trocar/retornar guia; Pular em cenas diferentes; situação de jogadores
incluindo rolagem e troca de slot. Limite desconhecido/zero e famílias não
reconhecidas não autorizam situação inventada nem nome de botão presumido.

## Retorno real dev 16 / entrega dev 17 — 19/10/2026

Prevalece sobre os estados históricos abaixo:

- 2 câmera e regressão estádio: corrigidos por confirmação do usuário.
- 3 treinamento: exercícios falam; guia ativa ao trocar continua pendente.
- 4 Champions: rótulos falam; valores/estados e mudanças laterais não falam.
- 9 revisão ML: inclui clubes indevidos; limitar a clube selecionado e elenco.
- 10 países: continuam silenciosos.
- 11 confirmação após voltar da edição: sem nova aprovação; segunda etapa ML
  já aprovada anteriormente continua aprovada.
- 12 exclusão/cursor aprovados; refinamento do perfil: rótulo fala sem conteúdo.
- 14 Pular: botão/tecla real continua ausente.
- 15 introdução/home ML: silêncio confirmado nesta passagem.
- 16 situação do elenco: sem confirmação nova; continua pendente.
- 1 título e 18 entrada de liga/clube: sem nova aprovação específica.
- 5/6/7/8/13/17 e retirada de tipos sintéticos: preservar aprovações anteriores.

Dev 17 instalada com mecanismos comuns descritos em
RETORNO-REAL-E-COMPONENTES-2026-10-19.pt-BR.md. 256 Lua por cópia/23 Python,
sandbox/14 assinaturas passaram. Sem audição dev 17: não fechar pendentes por
testes internos. Guia ativa, ícone/comando e seção/slot ainda exigem vínculo.
Captura dev 16 preservada; nova captura de uma sessão rearmada.

## Lote completo e captura dev 16 — 19/10/2026

Usuário pediu tentativa de todos os pendentes e ofereceu nova passagem. A matriz
integral, investigação existente, lacunas específicas e roteiro estão em
LOTE-COMPLETO-CAPTURA-2026-10-19.pt-BR.md. Captura estruturada preparada para
próxima abertura, automática por uma sessão; não é correção audível nova.
248 Lua por cópia e 21 Python, sandbox e assinaturas passaram. Nenhum relato
real encerrado. Permanecem estados/aprovações abaixo; obter associações dos
componentes da lista inteira antes de outra entrega declarada como correção.

## Retorno audível dev 14 / entrega dev 15 — 19/10/2026

Regressão relatada: estádio/altura da grama silenciosos. Entrada da câmera
continua sem fala, interior das opções fala; título do primeiro item ausente,
só descrição; Pular sem nome do botão. Não fechar nenhum desses relatos.
Investigar estruturas comuns, sem regras por tela. Evidências, reprodução do
conflito localização/valor e lacunas em PADROES-COMPONENTES-2026-10-19.pt-BR.md.

Dev 15 instalada: vínculo nativo do valor prevalece sobre registro provisório
como rótulo; padrão text externo/seletor reconhecido por tipo e ancestralidade.
245 Lua por cópia e 18 Python, sandbox e assinaturas passaram. Sem teste audível:
estádio e câmera não comprovados no jogo; título e Pular ainda sem solução.
Demais aprovações e pendências reais preservadas.

## Refatoração geral / entrega dev 14 — 19/10/2026

Dev 14 instalada após revisão da base atual com Game Access Kit. Limpeza de
código sem uso, fila de fala e resets centralizados, cancelamento de trabalho
atrasado e preservação de vínculos estruturais entre campos independentes.
241 Lua por cópia, 18 Python, sandbox e 14 assinaturas passaram. Fonte/instalação
iguais; jogo fechado na instalação. Relatório REFATORACAO-2026-10-19.pt-BR.md.
Sem validação audível dev 14: nenhuma pendência real encerrada nesta entrega.
As aprovações e os estados do retorno real abaixo continuam valendo.

## Atualização real dev 12 / entrega dev 13 — 19/10/2026

Prevalece sobre os estados históricos abaixo:

- 13: corrigido pelo usuário (valores ML).
- 11: segunda etapa ML lê OK corretamente; treinador lê na primeira vez, mas
  deixa de ler ao retornar da edição do nome. Parcial, não fechar inteiro.
- 1: título continua ausente; 2/9 e demais pendências sem aprovação real.
- 12: edição funciona; retirar Apagado/Deleted e anunciar somente conteúdo removido.
- 18 (novo): entrada na seleção de liga/clube silenciosa; às vezes fala só '-'.
- 3/4/15: mantêm estado não verificado especificamente.

Dev 13 instalada com leitor do renderer padrão, vínculo setName/jump pela
estrutura, carrosséis confirmados no quadro e exclusão sem prefixo. 235 Lua por
cópia e 18 Python, sandbox e assinaturas passaram; sem validação audível da dev 13.
Detalhes e limites em ENTRADA-E-RETORNO-2026-10-19.pt-BR.md. Pular e situação do
elenco seguem sem identificação comprovada. Não fechar relatos pelo teste interno.

## Entrega dev 12 — 19/10/2026

Instalada sem teste audível ainda. Travessia dos componentes delegados, ligação
estrutural de campos, atualização de valores e título único sem catálogo;
inserções silenciosas pelo mod, exclusão/cursor preservados. Relatório e matriz
de alcance: COMPONENTES-DELEGADOS-2026-10-19.pt-BR.md. 228 Lua por cópia e 16 Python,
sandbox e assinaturas passaram. Não fechar relatos reais por esses resultados.
Pular e situação do elenco permanecem lacunas explícitas de botão/seção/slot;
diagnóstico estrutural ampliado. Estados confirmados pelo usuário abaixo continuam
válidos. Não pedir nova passagem ampla como se o conjunto estivesse resolvido.

## Estado atual consolidado — retorno sobre dev 11, 19/10/2026

### Correção de estado pelo usuário — prevalece sobre a lista histórica abaixo

- Corrigidos por confirmação real do usuário: 5 (repetição Usuário 1/2),
  6 (conteúdo de outra tela), 7 (diálogos/opções), 8 (retorno da leitura),
  12 (exclusão e navegação no nome) e 17 (instruções automáticas).
- Não verificados nesta passagem: 3 (treinamento), 4 (Champions), 15 (home ML).
  Não classificar como falhas reproduzidas da dev 11 nem como resolvidos.
- Foco atual: 1 (título), 2 (entrada da câmera), 9 (revisão do elenco do clube),
  10 (países), 11 (Avançar/Confirmar), 13 (mudança dos valores ML),
  14 (botão real de Pular), 16 (situação do jogador na escalação).
- Refinamento do item 12, sem reabrir a falha corrigida: usuário prefere não
  ouvir caracteres enquanto digita, ou poder alternar isso com F2. Investigar
  origem do eco (mod/NVDA), evitar anúncios duplicados e verificar conflito de
  F2 antes de definir atalho. Preservar feedback de exclusão e revisão do cursor.
- Retirada de tipos sintéticos continua aprovada. Preservar os caminhos
  corrigidos e concentrar investigação no lote ainda sem solução.

A numeração abaixo é mantida como referência aos relatos; o estado acima é
o atual. Registro desta atualização não altera código nem build.

Usuário confirmou ouvindo: deixou de anunciar o tipo de controle, resultado
aprovado. Informa que os demais problemas permanecem; não equivale a nova
reprodução individual de todos os relatos antigos. Pendências consolidadas:

1. Título inicial: falta o começo Football Life.
2. Câmera: opções iniciais silenciosas; ajustes internos chegam a falar.
3. Escolha de treinamento silenciosa.
4. Configurações Champions: somente dificuldade lida, outros itens com falhas.
5. Usuário 1/2: repetição contínua até mudar de tela.
6. Contexto antigo: OK antecipado, Lista de jogadores do fundo na nacionalidade
   e opções da etapa anterior após avançar.
7. Opções/diálogos silenciosos: configuração básica do plano de jogo e diálogo
   do modo de edição. Preservar perguntas/respostas/entrevista já aprovadas.
8. Voltar/reentrar: demora ou silêncio antes de retomar leitura automática.
9. Escolha do clube para treinar: revisar clube e elenco apresentado com
   I/K/J/L, atualizando na troca. Analógico direito somente sem conflito.
10. Nacionalidade: países silenciosos depois de escolher continente.
11. Avançar/Confirmar silenciosos nas etapas do treinador e configuração ML;
    usar a legenda real, sem substituir nomes.
12. Nome do treinador: falta feedback de exclusão e navegação por caracteres.
13. Valores da configuração ML: moeda não anuncia mudança lateral. Frequência
    de transferências possivelmente afetada, citada com dúvida pelo usuário.
14. Pular: falta o nome do botão realmente apresentado junto à instrução.
15. Home ML: último relato de silêncio total; ler foco/textos principais,
    deixando calendário e demais informações na revisão sem despejar tudo.
16. Escalação: nomes dos jogadores lidos corretamente segundo novo relato,
    mas falta situação correta de titular/reserva/não relacionado. Retorna ao
    lote, superando adiamento anterior. Exigir prova de seção/slot.
17. Textos automáticos/instruções omitidos nas etapas do treinador, como
    Insira os detalhes do treinador e Escolha sua aparência. Relatos anteriores
    permanecem abertos; ausência de nova menção não comprova resolução.

Investigar mecanismos comuns de seleção, apresentação, valores, edição,
contexto e estados. Nesta atualização apenas documentação, sem mudar a build.

## Lote instalado após passagem por voz — 19/10/2026, dev 11

Relatos reais da dev 10, evidências, mudanças comuns e limites estão em
LOTE-VOZ-2026-10-19.pt-BR.md. Escalação explicitamente adiada. Home ML passou
a não ler nenhum item; países, confirmação, edição e botão de pular continuam
relatos reais abertos. Acrescentados título inicial incompleto, câmera na
entrada e pedido de revisão do elenco ao escolher clube. Remover globalmente
os complementos sintéticos de tipo/seleção na fala, mantendo dados reais.

Dev 11 instalada: recuperação do texto renderizado sem novo evento, descrição
ligada ao rótulo, revisão atualizada da árvore/painel do clube, primeiro título,
texto/cursor próprios do KeyboardPopup e nomes de glifos por fonte efetivamente
reconhecida. Não presumir que dígito seja botão ou que skin ps5 comprove glyph.
218 Lua por cópia, 15 Python, sandbox e 14 assinaturas passaram. Sem audição
da dev 11 no jogo. Fazer validação ampla; não fechar relatos pela suíte verde.

## Passagem por voz encerrada — 19/10/2026; implementação autorizada

Usuário autorizou compilar os dados e trabalhar no lote após encerrar a chamada.
Escalação explicitamente adiada, sem novo teste ou alteração de classificação
neste lote. A primeira tela/home da Master Liga agravou: na dev 10 agora não
lê nenhum item, antes ainda lia Avançar o tempo. É atualização do mesmo relato,
não uma pendência separada. Demais confirmações desta passagem estão acima
(no NOTEBOOK) e na seção de passagem por voz deste documento de testes.

Capturas desta build preservadas em tests/capture-dev10-2026-10-19-sider.log e
focus-trace correspondente. Elas comprovam execução dev 10, leitura de perguntas
e respostas em vários momentos e lacunas de seleção com cursor nativo resolvido.
Por isso a observação anterior sem validação audível da dev 10 está superada;
os relatos reais não foram resolvidos pela suíte de 202 testes.

## Passagem real por voz — 19/10/2026, dev 10, em andamento

Usuário está navegando e relatando; nesta etapa registrar, sem alterar a build
no meio da passagem. Consolidar correções ao final em lote, por mecanismos comuns.

- Menu principal: anúncio deveria incluir Football Life no início; atualmente
  ouve somente Amistosos, ligas e muito mais. Título inicial incompleto.
- Preferência geral nova: retirar da fala os complementos seletor, item
  selecionado, botão selecionado e equivalentes. Manter nomes e valores reais;
  não interpretar como pedido para remover todo feedback útil de estado.
- Entrada das configurações de câmera: opções de primeiro nível (offline,
  online e demais) silenciosas. Depois de abrir uma delas, os ajustes internos
  passam a ser lidos. Amostra de falha de seleção/apresentação inicial, não
  autorização para regra por nome da tela.
- Pedido de melhoria: na seleção de clube da Master Liga, disponibilizar na
  sequência de revisão I/K/J/L o nome do clube, a legenda real Lista de
  jogadores e os nomes do elenco exibido. Liverpool é exemplo, não tabela
  fixa. Associar a lista ao clube atual e descartar a anterior ao trocar clube.
  Analógico direito somente com ausência de conflito comprovada. Usuário não
  sabe se o componente também aparece fora da Master Liga; admite adaptação
  provisória ali se necessária, mas objetivo continua reutilizar o componente
  de elenco em outros contextos quando comprovado.

Registro de relatos e preferência, sem implementação nesta passagem. Não
considerar os sintomas anteriores resolvidos nem inferir conteúdo não observado.

### Confirmações durante a mesma passagem por voz

- Seleção de clube para treinar: é a lista de times; a melhoria pedida é revisar
  o elenco mostrado ao lado do clube escolhido, não navegar uma tela separada
  de lista de jogadores. Correção de entendimento confirmada pelo usuário.
- Após escolher Europa na configuração do treinador, os países permanecem
  silenciosos. Falha anterior reproduzida na dev 10, não nova pendência duplicada.
- Comandos de avanço/confirmar continuam silenciosos; o usuário confirmou
  tratar-se do mesmo ponto já relatado. Preservar a legenda real do jogo;
  OK, Confirmar e Avançar citados na fala não comprovam texto de cada widget.
- Edição do nome: Backspace não anuncia exclusão; setas não anunciam movimento
  pelo texto. Relato real nesta passagem, incluindo feedback de exclusão que
  tinha testes internos. Não inferir posição de edição; cursor nativo continua
  sem localização comprovada.
- Cenas: ouve apenas Pular, sem nome do botão. É o mesmo item 10 do relato
  anterior, agora confirmado ainda pendente na dev 10. Investigar a representação
  interna do ícone/botão efetivamente apresentado e a relação com a legenda.
  Options foi exemplo incerto do usuário, não identificação confirmada nem
  autorização para fixar um botão por plataforma ou pela cena.

## Lote geral — 19/10/2026, 0.1.7 dev 10

Todos os 11 relatos de 18/10 tratados no lote de mecanismos comuns. Matriz,
evidências, alterações e limites em LEITURA-COMPONENTES-2026-10-19.pt-BR.md.
Terceiro mapa de filhos, cursor reconciliado, texto final, campos repetidos,
ciclo de apresentação, diálogos pré-alocados, descarte geral de fala antiga,
revisão da árvore atual, ícone vinculado e seção do jogador com prova estrutural.
202 Lua por cópia, 12 Python, sandbox e 14 assinaturas passaram. Nenhum relato
real encerrado sem ouvir a dev 10. Fazer passagem ampla, sem pedir sessões
isoladas para cada tela. A situação do elenco pode ser omitida onde não há
cabeçalho/vínculo comprovado; inscrição por slots nativos continua em aberto.

## Relato real — 18/10/2026, dev 8; alterações locais dev 9

Lista completa, evidências e situação por sintoma em
INVESTIGACAO-2026-10-18.pt-BR.md. A dev 9 trata causas comuns de repetição,
ciclo de diálogos, apresentação durante construção e leitura de revisão/Pular.
183 Lua por cópia, nove Python, sandbox e assinaturas passaram. Os relatos
reais permanecem abertos até validação; países, botões de avançar, fundo,
conteúdo completo da home e distinção banco/não relacionados não estão comprovados.

## Correção comum — 14/10/2026, 0.1.7 dev 8

Captura dev 7 confirmou eventos de foco em conjuntos, não somente no texto
principal. Treinamento ficou em ambiguous-selection com texto do exercício e
resultado concorrentes; configurações propagaram eventos para nome, valor e
textos auxiliares. A dev 8 corrige agrupamento/elegibilidade e invalidação de
legendas de objetos reutilizados, sem consultar backups ou mapear telas.
Detalhes em CONTROLES-COMPOSTOS.pt-BR.md. 174 Lua por cópia, nove Python,
sandbox e assinaturas passaram. Não fechar os relatos reais até ouvir a dev 8.

## Relato real — 14/10/2026, 0.1.7 dev 7

- Na escolha do treinamento, a leitura continua ausente.
- Nas configurações da Champions, somente o nível de dificuldade foi lido;
  os demais itens não foram. Diego relata que esses itens eram lidos antes.

Não considerar a dev 7 validada para leitura geral. Não usar versões antigas
como rota de investigação. A exigência é resolver o mecanismo comum na base
atual, com aplicação a outros controles/telas, sem mapear estas telas pelo nome.
Regras permanentes registradas no AGENTS.md da raiz do workspace.

## Revisão geral — 0.1.7 dev 4

Diego corrigiu a legenda: a tela mostra **Confirmar**, conforme OCR; capturar
`OK` não autoriza atribuir esse texto ao botão visível. Relatou orientação
silenciosa, campos que deixaram de falar e edição sem apagamentos ou movimento
por caracteres. Exigiu revisão da base comum, evitando mais exceções por tela.

Revisão, pesquisa primária, mudanças e limitações em
`REVISAO-GERAL-LEITURA.pt-BR.md`. O leitor de cursor central segue sem seleção
comprovada nas capturas reais; cursor de edição também permanece não identificado.
Build local 4, versão base 0.1.7. Suíte `tests/core-review-suite.log` passou com
149 casos Lua por cópia, nove Python, sandbox e 13 assinaturas. Isso não fecha
as falhas de leitura reais nem comprova autonomia em telas não capturadas.

## Integração local — 09/10/2026, versão 0.1.9

Relato mais recente: OK anunciado em telas anteriores à sua aparição; títulos
automáticos como “Escolha sua aparência” ficaram silenciosos; apagamentos no
nome do treinador não tiveram retorno. **OK antecipado é independente do
teclado.** Não confundir essas duas falhas nem limitar a transição ao popup.

Capturas preservadas em `tests/capture-2026-10-09-integration-sider.log` e
`tests/capture-2026-10-09-integration-trace.log`. A fala registra OK em mais de
um widget, antes da abertura do teclado. A captura de fala sozinha não confirma
qual deles Diego via naquele instante. Registra também título da aparência,
reset de contexto Sider durante edição e teclado aberto com leitura do campo
do treinador ao fundo, sem retorno dos apagamentos.

Mudanças: orientação recebida durante construção espera ativação; orientações
pendentes já ativas sobrevivem ao reset de times do Sider. Rejeição de origem
desativada também vale quando a próxima janela ainda não tem árvore completa.
Percurso de janelas inclui ligação delegada e pai do cursor, com tipos e limites
validados. Isso amplia a associação de origem; não certifica todos os layouts.

Retorno da edição passa pelo setter nativo NodeRectTextInput, cuja string
armazenada fica em +0x118 (verificado no executável), e pelo processamento de
quadros. Apagar final “é” deve falar “Apagado. é”; apagar tudo informa o trecho
removido. Campos ao fundo e I/K/J/L não disputam a fala enquanto o teclado abre.

Fonte e instalação iguais. Backup 0.1.8 em
`backups/2026-10-09-integration/FLAccess.lua`. Suíte
`tests/integration-suite.log`: 142 casos Lua por cópia, nove Python, sandbox e
13 assinaturas nativas. Sete casos novos incluem testes integrados de captura,
ativação, reset, fila e entrega ao Prism com memória e saída simuladas. Não são
testes de navegação real dentro do jogo. Perguntas/respostas continuam cobertas
pelos testes anteriores.

Próxima validação: reiniciar para carregar 0.1.9; escolha do time, aparência,
detalhes do treinador e retorno. Conferir título automático e ausência de OK
antes de sua tela. Em separado, abrir nome, apagar letras/acentos/tudo, digitar,
fechar e conferir retomada. Avançar segue pendente de confirmação real.

## Preparado para teste — 09/10/2026, versão 0.1.8

Fonte e instalação atualizadas localmente. Backup anterior:
`backups/2026-10-09-transition/FLAccess.lua`. Suíte:
`tests/transition-suite.log`: 135 casos Lua por cópia, nove Python, sandbox
Sider e assinaturas dos 12 hooks passaram. Jogo fechado nesta etapa;
comportamento real ainda não confirmado.

A captura 0.1.7 foi cruzada com o relato. Textos antigos continuavam com a
marca de seleção depois de desativados, e alguns endereços eram reutilizados
para outros dados. Agora a leitura verifica também o estado atual do texto;
trocar de janela não transforma as marcas antigas em novas seleções.
Calendário, estádio e números estavam sendo anexados ao parágrafo anterior
por proximidade de tempo. Agora a união exige o mesmo widget.

Metadados de menus com marca `home` passam a encaminhar detalhes capturados
para o buffer único, sem anúncio automático de parágrafos. Essa indicação
vem do carregamento de recursos, não comprova sozinha qual tela está ativa:
validar especialmente retorno/reentrada com recursos em cache. Perguntas
estruturais encerram essa política e mantêm o leitor aprovado.

Nome do treinador passa a anunciar “ativar para editar”. Teclado nativo
reconhecido anuncia abertura; campos de entrada reconhecidos oferecem retorno
de acréscimos e apagamentos. Nomes internos desses campos ainda precisam de
confirmação no teclado real. Aviso Pular pode usar a legenda do botão do
mesmo conjunto de ícones; se não houver botão identificado, anuncia somente
a possibilidade de pular, sem inventar Options.

**Avançar permanece pendente.** A captura não trouxe sua legenda nem uma
seleção válida pelo cursor central. Registramos agora também tipo da raiz
e ponteiro de cursor para localizar a falha na próxima passagem.

Após reiniciar, testar detalhes do treinador e teclado, os dois Avançar,
perguntas/respostas, tela principal com I/K/J/L e aviso para pular. Voltar e
reentrar para conferir silêncio, fala antiga e política de detalhes.

## Teste real de Diego — 09/10/2026, versão 0.1.7

Relato do usuário; ainda não cruzado com os logs desta passagem.

Confirmado pelo teste: perguntas, respostas e entrevista estão funcionando
corretamente. Preservar esse comportamento nas próximas mudanças.

Pendências e comportamento desejado:

- Avançar continua quebrado. Não considerar resolvido pela nova base estrutural.
- Ao avançar na Master Liga, o leitor ainda anuncia opções da tela anterior.
  Investigar a janela ativa e a origem das falas pendentes nessa transição.
- Nome do treinador não é um seletor. É uma opção que abre um teclado para
  digitar o nome. Não descrevê-la como edição direta antes da ativação.
  Sugestão de anúncio: “Nome do treinador, [nome atual]. Ativar para editar”.
  Diego quer explorar aviso “Teclado aberto” e retorno acessível durante a
  digitação; determinar o retorno adequado conforme o teclado real do jogo.
- Após as perguntas, a tela principal da Master Liga anuncia calendário e
  demais informações em bloco. Leitura automática deve priorizar informações
  principais e seleção atual. Calendário deve ficar disponível para revisão
  usando I/K/J/L, em uma sequência única, sem separar em categorias.
- Avisos “Pressione [botão] para pular” não estão sendo lidos. Anunciar a
  possibilidade de pular com o botão realmente configurado/exibido pelo jogo;
  não presumir um botão fixo. Evitar repetir o aviso em cada redesenho.

Terminologia acordada: **teclas de navegação do mod** = I, K, J e L.
São teclas de revisão de leitura; não equivalem às setas de seleção do jogo.
Mantêm os comandos existentes: I anterior, K próximo, J primeiro, L repetir.

Prioridade seguinte: leitura da tela anterior após Avançar e identificação
do próprio Avançar; depois excesso de leitura na tela principal, avisos para
pular e interação com o teclado. Não alterar o caminho de perguntas/respostas
sem um teste de regressão que preserve o resultado real aprovado.

## Situação mais recente — base estrutural 0.1.7

Implementado leitor do gerenciador nativo de janelas e do cursor validado.
Consulta registros de janela, raiz e estado habilitado; filtra textos ligados
somente a janelas desativadas. Índices do cursor podem fornecer a seleção mesmo
sem alteração de cursorOver. Estruturas desconhecidas continuam com o leitor
anterior. Detalhes e limites em NATIVE-WINDOW-READER.pt-BR.md.

129 casos Lua por cópia, nove Python, sandbox e assinaturas dos 12 hooks
existentes passaram. Resultado real ainda pendente: jogo estava fechado durante
esta etapa. Reiniciar para carregar 0.1.7, passar por configurações e voltar;
depois detalhes do treinador, Avançar e pergunta com navegação das respostas.
Conferir native-window-reader, native-windows e native-cursor no sider.log.
Sem associação estrutural registrada, não declarar o problema resolvido.
Avançar ainda pode ser gráfico/sem texto; não foi inventada uma legenda.
Backup: backups/2026-10-08-native-window/FLAccess.lua. Log:
tests/native-window-suite.log. Buffer único e I/K/J/L preservados.

Registro: 8 de outubro de 2026. Teste manual por Diego; captura passiva pelo MCP do NVDA, cruzada com sider.log. Nenhuma tecla enviada pelo agente nesta sessão. Trabalho exclusivamente local.

## Falhas a corrigir

- [ ] P1 — Recuperação do foco e das transições. Diego relatou leitura engasgada/silenciosa ao navegar; entrar em Liga e voltar recuperou a leitura. Causa ainda não comprovada. Investigar geração do contexto, candidatos antigos e arbitragem do foco; não resolver apenas com mais exceções por tela.
- [ ] P1 — Isolamento de diálogo. Na saída da fase de grupos, o NVDA recebeu “Sim, botão selecionado” seguido de “Grupo B. Sim, botão selecionado”; também “Grupo C. Não, botão selecionado”. sider.log confirma passagem pelo leitor de diálogo e pelo adaptador de grupos. O diálogo deve ter prioridade exclusiva enquanto ativo; contexto do fundo não pode decorar seus botões.
- [ ] P1 — Separar texto informativo de seleção. Ao voltar ao menu principal, “Tron” e “Travis Scott” foram anunciados; artista apareceu como item selecionado, repetidamente. Não há evidência de que seja controle selecionável. Investigar identidade/papel do widget e elegibilidade para foco, sem depender de uma lista de músicas.
- [ ] P2 — Estabilidade nas transições. Captura contém “Desl.”, “OK” e cabeçalhos como seleção em momentos suspeitos, além de repetições de “UEFA Champions League”. Conferir contra intenção do jogador antes de classificar todos como erros; distinguir abertura, mudança real e redesenho.
- [ ] P2 — Retorno consistente. Repetir caminhos de ida e volta para verificar que a leitura volta imediatamente, sem precisar entrar em outra modalidade.

## O que funcionou nesta passagem

- Diego avaliou positivamente leitura da Champions e seleção de clubes.
- Captura incluiu navegação entre ligas, clubes e Liverpool.
- Configurações falaram nome, papel e valor: número de usuários, dificuldade, duração e lesões; mudanças de valor chegaram ao NVDA.
- Fase de grupos falou grupo e clube em várias mudanças. Ainda usa adaptador específico; não prova autonomia do leitor genérico.
- Amistoso produziu “Usuário 1, Em casa, selecionado” na última entrada. Isso não comprova todos os lados/retornos.

## Próximas áreas de teste

Fazer uma área por vez e voltar ao menu principal entre elas. Em cada área, mover devagar, depois rapidamente; voltar e entrar novamente. Anotar silêncio, item errado, repetição e contexto antigo. Não reiniciar o jogo ao primeiro problema: registrar se uma transição recupera a leitura.

1. Amistoso: Em casa/Fora, seleção de liga e time nos dois lados; uniformes, estádio e configurações pré-jogo, quando disponíveis.
2. Configurações do jogo: campos com valores, abas, opções desativadas; alterar e restaurar valores quando conveniente.
3. Liga: criação, seleção de competição/time e retorno; comparar com recuperação relatada no menu.
4. Copa/Champions: editar grupos, abrir/cancelar confirmações e voltar repetidamente; verificar isolamento de diálogo.
5. Plano de jogo: jogadores, reservas e submenus; identificar leitura correta de posição, seleção e mudança de contexto.

## Critérios para fechar as correções

- Seleção real é anunciada; música e texto de fundo não viram foco.
- Diálogo fala mensagem e botão ativo sem prefixo do fundo ou anúncio concorrente.
- Ida, volta e reentrada mantêm leitura; nenhum caminho exige recuperação por outra modalidade.
- Valores mudam na fala com o campo correto; redesenho não repete seleção sem necessidade.
- Validar no jogo, além dos testes locais. Captura de fala prova entrega ao NVDA, não prova sozinha que a seleção está correta.

## Continuidade

### Rodada integrada: contexto, padrões e buffer

Versão local 0.1.6 implementada e instalada. Guia em CONTEXTO-E-BUFFER.pt-BR.md; backup em backups/2026-10-08-context-buffer/FLAccess.lua. Leitor comum para respostas em foco primário, continuidade entre perguntas no mesmo enunciado, prioridades de fala e buffer (atalhos atualizados abaixo). Fonte e instalação passaram 103 casos Lua por cópia e restante da suíte; não equivale a validação no jogo.

Próximo teste prioritário: perguntas iniciais da Liga Master, passando por respostas, confirmação e pergunta seguinte; consultar pergunta e resposta com Ctrl+setas. Depois configurações, diálogo sobre grupos, retorno e música. Se houver silêncio, correlacionar dialog-selection-unresolved com captura real. Informações no buffer ainda são restritas aos leitores já comprovados; proprietário global dos painéis permanece não resolvido.

### Correções locais após as três amostras

Implementadas e instaladas em 8 de outubro; validação no jogo ainda pendente. Backup anterior: `backups/2026-10-08-reading-regressions/FLAccess.lua`.

- Rótulos de configurações conhecidos agora entram na leitura real de foco; antes eram excluídos do rastreamento por `is_selector_label`.
- Fronteira de título preserva controles catalogados e sliders criados no mesmo frame, mantendo papel e valor. Título estrutural de submenu desativa leitor horizontal da pré-partida.
- `No String` e `/` deixam de provocar limpeza global da navegação; o marcador é descartado. Antes podia apagar vínculos recém-criados, além de ser falado.
- Ajuda de opções, quando vinculada a uma superfície com controles observados, sai da fila modal e é agendada após leitura do campo. Tutoriais e parágrafos isolados continuam cobertos pelos testes anteriores.
- Diálogo Sim/Não ativo impede leitor genérico/grupos de emitir o mesmo botão. Foco de uma nova tela ainda pode expirar diálogo antigo.
- Bancos secundários não concedem foco a texto arbitrário sem controle comprovado ou adaptador ativo. Isso cobre o padrão capturado do artista em 0x114/0x100; leitura de nome da faixa como título ainda requer confirmação no jogo e identificação estrutural se persistir.

Validação: 85 casos Lua na fonte e no módulo instalado, nove testes Python, sandbox Sider e 12 prologues do executável passaram. Resultado: `tests/reading-regressions-suite.log`. Não significa que todas as telas estejam corrigidas no jogo. Permanecem por validar sliders de câmera/som, transições/Uniforme, recuperação do menu e anúncio da faixa musical; botão omitido na instrução ainda não foi identificado.

Próxima rodada: reiniciar o jogo para carregar o módulo atualizado; testar primeiro configurações gerais (nome/valor antes da ajuda), câmera/som e diálogo de saída dos grupos, depois voltar ao menu principal. Coletar MCP incrementalmente durante o percurso para evitar expiração da sessão.

### Terceira rodada: repetição com NVDA

Sessão live/expert reconectada em 8 de outubro. O bridge encerrou a sessão por `inactivity-timeout` às 02:14:56; a consulta posterior não tinha conexão ativa, mas o arquivo persistente da sessão preservou a fala. Evidência recuperada em `tests/capture-2026-10-08-repeticao-nvda.log`. Isso confirma captura das emissões, não a conclusão audível de cada frase.

- Confirmado no registro do NVDA: configurações gerais emitiram ajuda de duração, prorrogação, pênaltis e substituições, sem nome/valor correspondente nessas entradas. A duração emitiu 9, 8, 9 e 10 minutos quando alterada. O campo inicial de dificuldade emitiu nome e valor corretamente.
- Confirmado no registro do NVDA: câmera emitiu “Modo offline (Normal)” sem anúncios de Zoom, Altura ou Ângulo no trecho, apesar do mapeamento desses sliders no mod. Não conclui sozinho quais movimentos foram feitos dentro dessa tela.
- Confirmado no registro do NVDA: “No String” foi emitido duas vezes após configurações do sistema.
- Estádio registrou nome/valor e mudança para Spotify Camp Nou. Uniforme continua suspeito pela sequência Uniforme/Estádio/Voltar; é preciso confirmar intenção/seleção real antes de fechar causa.
- O trecho do mod desta rodada terminou em configurações do sistema/velocidade do jogo. Não há evidência de repetição da tela de som nesta rodada.

Próximo passo: corrigir primeiro prioridade da fala de campos sobre ajuda e isolamento de contexto; depois ligação do foco aos sliders e filtragem de texto inválido. A amostra já permite iniciar investigação das correções. Para futuros testes, consultar o bridge durante a navegação para manter a sessão e salvar capturas incrementais.

### Segunda rodada: amistoso e configurações

Diego relatou muitos erros. Nesta consulta o MCP informou que não havia leitor conectado; portanto os achados abaixo vêm de sider.log, que registra o envio pelo módulo, sem comprovar entrega ou conclusão audível no NVDA. Recorte preservado em `tests/capture-2026-10-08-amistoso-sider.log`.

- [ ] P1 — Prioridade entre campo e ajuda. Em configurações gerais há vários anúncios de explicação (duração, prorrogação, pênaltis e substituições) sem anúncio correspondente de nome/valor nos registros de fala. Investigar se ajuda interrompe ou substitui a leitura do controle. Não desligar ajuda como substituto para corrigir arbitragem.
- [ ] P1 — Sliders sem leitura de foco/valor nesta passagem. Câmera mapeou Zoom, Altura e Ângulo; som mapeou sete sliders. O mapeamento existe, mas não aparece anúncio dos controles nesses trechos; câmera falou principalmente Voltar/OK e instrução. Confirmar passos do jogador e ligação entre foco, objeto nativo e fala.
- [ ] P1 — Contexto de fundo no submenu. Após “Uniforme”, o módulo enviou “Estádio, item selecionado”. Suspeita de foco do menu anterior; conferir seleção real e bloquear adaptador do fundo enquanto submenu estiver ativo.
- [ ] P2 — Texto técnico indevido. Entrada nas configurações do sistema enviou “No String”. Investigar origem e descartar marcador inválido sem silenciar títulos válidos.
- [ ] P2 — Controle ausente na instrução. Mensagem de câmera contém “pressione  para alternar”; identificar símbolo/botão omitido e fornecer nome acessível.
- Mudanças na altura da grama e dificuldade falaram apenas valor após nome inicial. Pode ser comportamento adequado dentro do mesmo campo; não tratar como erro isoladamente.

Conclusão desta rodada: reconhecer/mapeiar um controle ainda não garante que o leitor anuncie seu foco. Priorizar arbitragem de contexto e de fala antes de acrescentar regras por tela.

Estado: versão local 0.1.6 com contexto e buffer instalada; aguardando validação no jogo. Jogador controla o jogo. Não alterar o módulo durante uma coleta. Atualizar este arquivo após cada rodada com área, resultado e evidência.

Atualização de comandos: lista única, sem categorias; Ctrl+↑/↓ anterior/próximo, Ctrl+← primeiro, Ctrl+→ repetir. Atributos na mesma lista. Analógico direito restrito ao painel reconhecido de atributos. Testar se Ctrl+setas também move o cursor do jogo: bloqueio nativo das setas ainda não implementado.

Rodada posterior: Ctrl+setas descartado por conflito relatado. Comandos atuais I/K/J/L (anterior/próximo/primeiro/repetir), sem categorias. Corrigida conversão literal de OK para Avançar e rejeitado candidato de botão antigo durante mensagem nova. Proteção de transição usa objeto e ativação nova, não apenas caption. 107 casos Lua; log letter-review-suite.log. Autonomia de painel sobreposto e silêncio após OK do treinador continuam dependendo de validação real; trecho do sider.log termina antes dessa navegação. Guia CONTEXTO-E-BUFFER.pt-BR.md atualizado.

## Investigação de silêncio após Roupa em jogos

Evidência preservada em tests/capture-2026-10-08-treinador-sider.log. Uma fala completa de Roupa em jogos/Terno é seguida por várias decisões para o mesmo objeto em +0x100, sem novas falas. As amostras seguintes não apresentam candidatos em +0x104 e o indicador em +0x100 conserva idade crescente. Isso comprova retenção do indicador e corte de repetição na rota do controle; não identifica o campo que o jogo realmente selecionou depois. O mod observa textos, mas ainda não conhece a autoridade global de seleção/visibilidade do painel.

Correções comuns: perda ou troca de foco invalida a lembrança de anúncio do controle; retornar ao mesmo campo pode falar com valor igual. A lembrança continua impedindo repetição enquanto a seleção permanece estável. Um banco secundário antigo não supera ativação primária mais recente nas rotas genéricas; adaptadores existentes continuam responsáveis por suas telas comprovadas. Não foi acrescentada exceção pelo texto Roupa em jogos ou pelo menu de treinador.

Nova captura automática em SiderAddons/FLAccess-focus-trace.log. Até 120 entradas de navegação/confirmar/voltar e 2 MiB por sessão. Observa até 80 objetos recentes, campos de +0x30 a +0x17c, nomes estruturais, identidades, rótulo/valor reconhecido e motivo do foco. Registra estado no input e mudanças após quatro e doze quadros; valores que viram zero também entram. O ponteiro candidato em +0x38 não vira prova de proprietário nem de visibilidade. Arquivo é reiniciado na primeira captura de uma nova execução. A leitura continua pelo mesmo canal Prism.

Próximo teste necessário: reiniciar e ir diretamente às opções do treinador; confirmar a introdução, navegar por todos os campos, voltar ao nome e roupa e retornar à tela anterior. Não é necessário ligar diagnóstico nem MCP. Após o trecho, correlacionar o novo trace com sider.log para procurar o estado/objeto que realmente muda na seleção. O trace pode apontar candidatos; identificar um gerenciador ou setter comum ainda exige confirmação, não apenas escolher o offset que coincida numa única tela.

Validação: 111 casos Lua por cópia, demais verificações da suíte e teste de captura sem fala. Log tests/focus-lifetime-suite.log. Backup backups/2026-10-08-focus-lifetime/FLAccess.lua. Resultado no jogo ainda pendente.

## Captura seguinte: causa do silêncio comprovada

Evidência preservada em tests/capture-2026-10-08-trainer-ambiguity-sider.log e tests/capture-2026-10-08-trainer-ambiguity-trace.log. Na geração 10, pares Nome do treinador/Luis Figo, Nacional./Região/PORTUGAL e Roupa em jogos/Terno mudam juntos: +0x104 passa a 1 nos dois objetos na mesma ativação. O leitor registra ambiguous-selection em cada movimento porque compara widgets independentes. Portanto, nesta captura o foco primário existe e acompanha a navegação; o problema é a representação de um único controle por dois widgets. A hipótese anterior de perda do sinal primário não explica o silêncio desta rodada.

Correção geral: o resolvedor agrupa candidatos somente quando já pertencem à mesma relação rótulo/valor aceita pelo leitor. A ativação do controle é a maior ativação dos seus componentes; quando disponível, seu rótulo representa a seleção. Texto igual, endereço parecido e controles diferentes não bastam para agrupar. Duas relações diferentes empatadas continuam ambíguas. Não há comparação pelo nome da tela de treinador.

O Voltar anunciado em +0x100 tem nome interno text e compartilha o link +0x38 com os objetos padIcon. A legenda Confirmar usa a mesma família. Os campos e os botões OK usam outros links. A implementação reconhece esse grupo observado de legendas: padIcon não vira controle/valor; caption text com papel dialog-button e mesmo link de padIcon não pode ganhar seleção de banco secundário. Se o caption tiver foco primário real, continua elegível. Isso não transforma +0x38 em prova universal de proprietário ou visibilidade; é uma relação local confirmada nesta família de interface.

115 casos Lua por cópia e suíte completa passaram; quatro casos novos cobrem foco simultâneo no par inédito, reprodução dos três campos capturados e revisita, empate entre dois controles distintos e legenda de comando versus botão em foco primário. Log tests/semantic-focus-suite.log. Backup backups/2026-10-08-semantic-focus/FLAccess.lua.

Validar no jogo: depois de reiniciar, chegar à introdução do treinador, confirmar OK, passar por nome, nacionalidade e roupa, retornar ao nome e à roupa, e voltar uma tela. Conferir leitura de cada campo/valor e ausência do Voltar indevido. A correção reproduz os sinais capturados offline; o resultado audível desta instalação ainda precisa dessa validação. Outros padrões sem relação reconhecida e a autoridade global de painel permanecem investigação aberta.

## Liga Master: Avançar, fundo e opções do diálogo

Captura preservada em tests/capture-2026-10-08-master-question-sider.log e tests/capture-2026-10-08-master-question-trace.log. Leitura de Nome do treinador/Roupa em jogos passou a ocorrer na passagem real. Permanecem relatos de Avançar mudo nas duas telas, início estranho das configurações e campos antigos lidos após prosseguir.

O enunciado usa question; a introdução usa eventMsg; ambos compartilham +0x38 com as respostas text. Nesta família, o leitor anterior tratava cada opção longa como parágrafo, incluindo as duas propostas de objetivos, e não mantinha um contexto interativo para a introdução. Unidade monetária conservou +0x104=1 no fundo e reapareceu entre respostas. As opções longas também não entravam de modo confiável no inventário de foco por causa do limite e da classificação como mensagem.

Correção integrada: eventMsg estabelece escopo de diálogo no grupo observado e bloqueia os campos de configuração atrás dele. question inicia a pergunta, reúne respostas text do mesmo grupo e substitui o lote de parágrafos previamente enfileirado pelo enunciado. Pergunta recebe prefixo Pergunta:; opções não são lidas automaticamente em conjunto nem há anúncio automático da primeira resposta antes de navegação. Cada seleção usa o foco primário da resposta vinculada, mesmo para texto longo antes capturado. Confirmar conserva o escopo durante a passagem à próxima mensagem; título estrutural reconhecido/reset encerra esse vínculo. Relação +0x38 continua específica ao padrão observado, não gerenciador global comprovado.

Outra correção: limpar texto de um ícone não reinicializa a deduplicação de um controle que continua selecionado. Anteriormente, limpeza de qualquer widget podia rearmar o campo e causar repetição sem movimento.

Pendentes expressos: Avançar não apareceu como caption nos objetos capturados; não foi inventado nem renomeado um comando para substituí-lo. Captura agora registra também alterações em até 16 objetos candidatos apontados por +0x38, lendo apenas 0x100 bytes por candidato validado. Serve para investigar os grupos/controle sem texto; não fornece autoridade de foco automaticamente. Início das configurações e trecho após Avançar antes de eventMsg ainda exigem validação/investigação; não foram declarados resolvidos.

118 casos Lua por cópia e suíte completa passaram. Casos novos reproduzem pergunta com Concordo e duas opções longas, campo antigo em foco no fundo, resposta após navegação, confirmação sem liberar a moeda antiga, chegada de eventMsg antes da pergunta e limpeza de ícone sem repetição do controle. Log tests/question-panel-suite.log. Backup backups/2026-10-08-question-panel/FLAccess.lua.

Próxima passagem útil: após reiniciar, parar no Avançar do treinador e mover uma posição antes/depois algumas vezes; confirmar, fazer o mesmo no Avançar das configurações e seguir à pergunta. A captura é automática e não exige MCP. Na pergunta, ouvir enunciado, percorrer todas as respostas e revisitar uma delas. Resultado audível desta nova versão ainda pendente.
