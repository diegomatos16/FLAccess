# Testes com Football Life em execução

Estado: **pendentes de execução humana**. A suíte offline não valida memória do
processo, foco real, temporização da renderização, voz física nem estabilidade do
Sider durante uma partida. Execute com o `FL_2026.exe` e o `SiderAddons` desta
instalação. Anote versão do jogo, leitor de telas, idioma, ações, fala observada
e resultado. Em falha, preserve `SiderAddons/sider.log` e, quando útil, ative o
diagnóstico somente para a tela problemática.

## Roteiro

1. **Inicialização e primeiro uso.** Inicie em português; passe pelas escolhas
   de idioma e controles antes do menu principal. Cada foco real deve falar uma
   vez. Repita em inglês. Nenhum painel deve ficar mudo ou falar texto de tela
   anterior. Verifique que NVDA recebe fala e que SAPI funciona sem leitor.
2. **Menu principal e Sider.** Entre, volte e repita Football Life, Liga Master
   e Configurações. Navegue lentamente e depois rapidamente. Anúncio deve
   acompanhar último foco estável. Abra painel do Sider; confirme título e
   opção atual. Alterne `Ler tooltips`; com opção desligada, tooltips tardios
   devem sumir. Feche painel; leitura do jogo deve voltar. Troque para outro
   módulo com texto: primeira abertura lê painel completo, alterações leem
   somente conteúdo alterado.
3. **Áudio e sliders.** Percorra controles de volume. Primeiro foco deve falar
   nome, tipo e valor; mudanças laterais devem falar só novo valor. Repetir
   mesmo valor não deve produzir sequência duplicada. Entradas sem rótulo no
   jogo não devem ganhar nome inventado.
4. **Seleção de lado, liga e clubes.** No amistoso, percorra Em casa, Neutro e
   Fora; depois lista de ligas, time da casa e visitante. A célula central da
   lista deve ser falada. Navegação rápida não deve ler clube antigo. Volte à
   seleção e repita para procurar estado obsoleto. Com vários controles, registre
   qualquer divergência separadamente.
5. **Pré-partida e aviso de retorno.** Ao entrar, escute mensagem completa de
   prontidão antes do primeiro comando. Navegue por Uniforme, Estádio, Plano de
   jogo e Início. Volte para acionar aviso de perda de configurações. Texto do
   aviso deve ser lido antes de Sim/Não; botão deve entrar na fila, sem cortar
   parágrafo. Cancele, navegue, abra aviso de novo, confirme. Botões antigos não
   devem roubar foco na tela seguinte; navegação não deve fechar o jogo.
   Durante leitura, navegue rapidamente entre botões: nenhum deve interromper
   mensagem; depois deve ser falado apenas o último foco útil. Repita: mova
   uma vez durante a fala, pare a voz pelo NVDA, aguarde um instante e mova
   novamente. O foco deve voltar a ser anunciado sem avançar de tela. Teste
   também Sim e Não em outras confirmações, não só neste aviso.
6. **Estádio.** Percorra Estádio, Período, Estação do ano/Clima, Altura da grama
   e Condições do campo. Cada linha deve falar nome, seletor e valor. Volte e
   reabra: valores não devem ser atribuídos à linha anterior.
7. **Copa e grupos.** Entre em configuração de copa e tabela de grupos. Mensagem
   introdutória deve sair antes do primeiro time. O `OK` antes da mensagem ou
   no fim da fileira deve permanecer mudo nessa grade. Navegue nas oito colunas e
   quatro linhas: `Grupo A` a `Grupo H` somente ao mudar de grupo. `Cancelar`,
   `OK` e outros comandos não devem ser anunciados como time. Saia para Plano
   de jogo e depois Configurações do sistema; células antigas não devem manter
   a tabela de grupos ativa. Em Copa > Novo, `Escolha em qual competição você
   quer entrar` deve ser lido sem prefixo de opção anterior como `Disputa do
   3º lugar`.
8. **Plano de jogo.** Entre/sai de visão principal, Menu de configuração básica,
   Configurações táticas básicas e Alterar formação. Ação A e retorno B/Escape
   devem manter contexto e permitir novo foco. Formação deve usar número entre
   parênteses, sem ler duas formações. Em táticas, nome, tipo e valor precedem
   tooltip; mudança lateral fala valor atualizado. Repita entrada/saída várias
   vezes. Na 0.1.5 essas telas ainda são experimentais: registre silêncio ou
   fala de jogadores de fundo como falha, não como aprovação. Na visão principal,
   percorra Táticas, Escalação/Editar posição e os demais comandos; nenhum
   cartão de jogador deve encobrir a opção escolhida.
9. **Tutorial paginado e Editar posição.** Avance páginas de instrução com A,
   direcional e analógico. Leia página anterior antes da próxima; marcadores de
   controle devem ter nome falável. Navegue jogadores e abra atributos com Y;
   nome, posição e valores precisam pertencer ao jogador atual. Feche com Y/B,
   repita e confira que nomes de fundo não sequestram o foco.
9a. **Liga Master, apresentação e aparência.** Ao avançar na apresentação,
    confira a leitura automática do parágrafo que começa com `Há muitas
    escolhas na carreira de um jogador de futebol`. Em avisos de uma ação,
    ouça o texto completo antes de `Avançar`, uma única vez. Na tela seguinte,
    `Escolha sua aparência` deve sair como título sem mover o foco. Percorra
    Nome do treinador, Nacional./Região e Roupa em jogos: cada linha com valor
    mapeado deve dizer rótulo e valor atual no primeiro foco; mudar à esquerda
    ou direita deve atualizar o valor. Repita rapidamente e depois volte ao
    mesmo item, verificando que ele volta a falar.
9b. **Navegação rápida.** Em configurações da Champions, altere Número de
    usuários depressa: deve falar o valor numérico, nunca `Voltar` ou `OK` como
    valor. Repita na pré-partida e no Plano de jogo. O último foco estável deve
    ser dito, sem silêncio permanente nem voz cortando avisos.
10. **Leitor de telas e foco do Windows.** Durante fala, feche NVDA e confira
    fallback SAPI; reabra NVDA e confira retorno. Minimize ou alterne janela do
    jogo: FLAccess não deve falar menus em segundo plano. Volte ao jogo e
    confirme que o foco atual volta a ser anunciado sem fala acumulada.
11. **Sider modificado.** Percorra pré-partida e painéis de outros módulos por
    vários minutos. Não deve ocorrer access violation. O evento
    `overlay_content` precisa acompanhar abertura, mudança e fechamento.

Se qualquer passo falhar, registre sequência exata de teclas/botões, tela,
idioma, leitor ativo, frase esperada e frase ou silêncio observado. Não marque
um caso como aprovado apenas porque passou no sandbox Lua.
