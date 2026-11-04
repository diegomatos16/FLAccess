# Reader50 — listas, classificação e data da Master Liga

Retorno49: listas e classificação continuam lentas; somente cinco times
alcançados; falta data da Master Liga e melhora da exploração. Usuário confirmou
usar setas/direcional do jogo para tentar descer na tabela. Não atribuir isso
ao uso de I/K. Correções de Configurações e Sim/Não continuam aprovadas48.

## Controles oficiais pesquisados

O [manual oficial disponível do PES2019 para PC](https://dds.konami.com/games/manual/pes2019/PC/pt-br/start.html)
documenta analógico esquerdo/direcional para selecionar opções, A para confirmar
e B para cancelar. Recomenda a Ajuda da tela para comandos específicos; no
layout Xbox do manual esse botão é View. [Menu principal](https://dds.konami.com/games/manual/pes2019/PC/pt-br/menu.html)
usa LB/RB para alternar o menu superior. Configurações podem ser personalizadas.

Não foi encontrado manual oficial acessível do PES2021/FL27 que confirme um
comando específico para rolar essa classificação. Não apresentar controles do
PES2019 como comprovação de todos os controles do FL27. A própria
[página oficial do FL27](https://www.pessmokepatch.com/2026/10/spfl27.html?m=1)
registra mudanças internas em competições e opções de controle no Switcher.
O leitor continua seguindo o índice nativo, sem enviar teclas ou escrever cursor.

## Maior custo medido no49

Captura preservada em `.test-temp/fl27-audit/sider49-return.log`. Há trechos
com9–15ms por quadro somente em `windows-ms`, contra menos de1ms em foco,
e captura desativada. Exemplo: média18,103ms,14,807ms em janelas,1,942ms em
textos, zero chamadas de fala. Outro trecho:20,908ms,13,270ms em janelas e
4,812ms em textos. A maior parcela medida era reconstrução, não Prism.

50 reaproveita a estrutura de menus já descoberta pelo cache existente de
até seis quadros. Cursor, janela, contêiner e texto usados são lidos novamente.
Cada ligação usada é validada contra o contêiner atual: ponteiro do delegate,
intervalo/slot do vetor ou registro da árvore MSVC e caminho até seu cabeçalho.
Preserva o guard de proprietário do LoaderSwf. Objetos removidos/recriados,
árvores cíclicas e janela fechada falham. Resultados escalares dessas verificações
duram apenas a fase síncrona; não atravessam Prism IPC. Percurso incompleto ou
subárvore desconhecida usa o caminho anterior de descoberta.

No teste controlado com100 ramificações, percurso completo707 leituras;
quadro estável91, incluindo verificação do cursor e da ligação realmente usada.
Isso mede chamadas ao leitor de escalares no teste, não FPS nem cópias reais
do jogo. Desempenho real50 ainda não confirmado.

## Classificação

MenuModeCmnStandingsMenu é reconhecido por vtable2684408, destrutor aed5d0
e callback de linha aedf80. Esse callback usa vetor de IDs em Window+90/+98.
O getter nativo e3d140 consulta o selector kind16 do GRUPO, mesmo quando o
cursor externo permanece na primeira ficha. O código anterior descia dentro
da primeira ficha; agora resolve o índice nativo e a linha no grupo correto.
Quando existem vários selectors kind16, segue o primeiro na ordem nativa,
como faz e3d1a9/e4d1c0; não rejeita a lista apenas por haver outros selectors.
Limite48 registros vem do renderer; não há limite artificial de cinco times.

Fala automática continua registro completo, na ordem time, posição, pontos,
saldo e demais estatísticas. Para evitar interrupções a cada célula atualizada,
a publicação automática exige a mesma assinatura em outro quadro. Não é pausa
pedida ao jogador. Exploração continua um campo completo por passo, lendo a
linha atual; mudança de seleção invalida campos já enfileirados.

Índice inválido/linha indisponível produz tabela reconhecida sem liberar clubes
de outras linhas. Log mudança-a-mudança `standings-selection` registra índice,
quantidade e ponteiro da linha para validar rolagem real sem captura completa.

## Data e exploração

Getter nativo15765e0 copia Date do estado da carreira: u16 ano,u8 mês,u8 dia
em Data+1642a24. Manager vem de3705e10 e Data de Manager+48. Contratos do
executável verificam esses campos e o formato de Date. Scope exige MainMenuML
atual, tipado e habilitado; ponteiros/ano/mês/dia são validados antes de falar.

Anuncia `Data: DD/MM/AAAA` ao entrar e disponibiliza como primeiro campo da
exploração. Não usa a data do computador, o último save nem schedule_date de
uma partida. Só considera anúncio entregue após sucesso do Prism; data/tela
mudada invalida fala antiga. Nova data pode ser anunciada após avanço do tempo.

Analógico direito coleta o buffer uma vez por passo; elimina a coleta completa
que antes servia apenas para testar disponibilidade. Continua um campo por
passo e silêncio quando não há conteúdo. I inicial vai ao último campo,
consistente com o movimento anterior das outras formas de exploração.
Repetir continua removido. J/L entre notícias ainda não implementados.

## Validação e limites

441 verificações Lua do leitor; novos casos incluem ligações removidas/cíclicas,
janela fechada, guard SWF, classificação de20 clubes com cursor externo fixo,
atualização de colunas, rejeição de fila da linha anterior, data na entrada e
exploração, data inválida/bissexto/tela fechada e uma coleta por passo direito.

66 testes Python:65 passam,1 ignorado por captura histórica ausente. Incluem
43 contratos de leitura do executável FL27, incluindo os novos getter Date e
callback de classificação. Integração29 módulos,16 eventos,23 registros,
120 quadros e Prism nativo. Resultado não equivale a audição/rolagem/FPS real.

Notícias J/L, cartão Diário e agrupamento específico liga/participantes continuam
pendentes. Índice correto, estabilidade da tabela, data real e desempenho50
aguardam confirmação do usuário. Não fechar esses relatos por teste simulado.

Fonte canônica `C:/Users/Diego/git/diegomatos16/FLAccess/modules/FlAccess`.
Gameplay19, Prism, DLLs, sons, perfis e configurações preservados. Instalação
pelo instalador com backup no Sider do FL27; captura completa não rearmada.
Sem publicação, commit, push ou tag.

Instalado e conferido:29 módulos idênticos à fonte,30 recursos e3DLLs iguais ao
backup; FlAccess.ini e sider.ini idênticos em bytes. Captura continua `consumed`.
Backup `local-backups/flaccess020-install-20261103-014733-801014`. Pacote local
atualizado em `release/0.2.0-local/FlAccess.zip`, metadados build50.
