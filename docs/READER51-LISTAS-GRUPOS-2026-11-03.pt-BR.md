# Reader51 — listas rápidas e agrupamento comum

Retorno do usuário: Reader50 ainda deixa listas de clubes, ligas e busca muito
lentas. No painel de Salah há dados em tabela, mas a exploração solta rótulos
sem valores. Não considerar esses relatos resolvidos por testes simulados.

## Evidência e divisão

Log50 preservado em `.test-temp/fl27-audit/sider50-return.log`: janelas consomem
cerca de 7–14 ms por quadro; na busca, média total de 21,332 ms, máximo172 ms e
1258 cópias de memória por quadro em um intervalo. O painel informativo272d998
está habilitado sem cursor. Campos apenas apresentados podem ter estado7,
enquanto o caminho anterior exigia participação de entrada263.

Dois componentes reais do Sider, sem carregador paralelo:

- `reader_lists.lua`: seleção nativa, países/equipes e atualização leve da
  janela. Carregado depois de controls, antes de observations.
- `reader_groups.lua`: associação comum entre rótulos, valores e títulos.
  Carregado depois de semantics, antes de records/review.

Total31 módulos. Eventos16 e registros23 preservados. `reader_records` continua
com os adaptadores tipados de classificação, calendário e saves; compartilha o
motor de pares com painéis apenas informativos. O Sider continua gerenciando os
módulos; recursos permanecem em content/FlAccess, sem mudança de CPK.

## Caminho das listas

Quadros estáveis validam cabeçalhos do gerenciador, registros de janelas, input,
raízes, relações Task, vetores de componentes e cursor. Não remontam todos os
membros nem os relatórios de diagnóstico. Mudança de cursor resolve imediatamente
a seleção a partir do grafo já descoberto. Mudança de dono, componente, registro,
guia ou foco desconhecido força descoberta completa; também há descoberta
periódica em até6 quadros. Memória ausente desativa o caminho leve.

Somente topologia é reaproveitada. Textos, escalares e ligações efetivamente
consumidas são validados novamente; cache de leitura não atravessa a entrega ao
Prism. Fechamento de diálogo é verificado inclusive no quadro leve. A leitura
dos nomes do painel de jogador controlado só roda quando existe o painel nativo
Parameter; não percorre todos os nomes históricos nas listas comuns.

A montagem de registros verifica primeiro se o campo pertence ao registro atual,
antes de validar a ligação nativa e ler texto. O teste com1000 campos alheios faz
zero validações desses campos; os dois campos selecionados exigem6 validações
no conjunto dos getters. Não é medição de FPS do jogo.

## Agrupamento e exploração

O motor usa nomes nativos de componentes e ancestralidade no mesmo dono/raiz.
Reconhece famílias `_item`/`_value`, `_label`, `_headline`, item_N/value_N e
campos estruturais já conhecidos. Primeiro associa irmãos; coluna compartilhada
só é aceita quando o rótulo e o valor são únicos no componente. Duplicatas
ambíguas e donos distintos não são combinados. Não usa tradução, proximidade
visual, ordem de escrita ou uma lista de nomes de telas para inventar relações.

Painéis sem cursor leem os valores renderizados diretamente, incluindo estado7;
não precisam receber foco. A fala ainda exige dono atual, valores e grafo válidos.
Assim o padrão de dados físicos pode ser reaproveitado em outras telas que
exponham a mesma estrutura. Layouts sem relações comprovadas continuam exigindo
investigação; não há promessa de reconhecer qualquer tabela do jogo.

Decisão confirmada: título real do grupo junto do primeiro campo ao entrar nele;
exemplo: “Dados físicos. Altura: 1,75 metros”. Próximo passo: “Peso: 72 quilos”.
Ao mudar de grupo, voltar a outro grupo ou pedir o primeiro campo, o título volta
a acompanhar esse campo. Sem título nativo inequívoco, lê apenas o campo.
Mudança do título ou valor antes da entrega invalida a fala antiga.

Atributos permanecem só na exploração; nome/situação continuam automáticos e a
classificação continua agrupada automaticamente. I/K e analógico direito vertical
mantêm um campo por passo; repetir continua removido. J/L nas notícias permanece
pendente. Não alterar cursor nem enviar comandos ao jogo.

## Verificação

447 verificações Lua: inclui campos de estado7, títulos por grupo, retorno ao
grupo, título/valor antigo, dono fechado, duplicatas e isolamento entre donos;
lista estável sem descoberta completa, cursor alterado no mesmo quadro,
redescoberta periódica e invalidação dos cabeçalhos. Contratos do executável
continuam usando o FL27 real. Integração31 módulos com120 quadros e Prism nativo.

66 testes Python:65 passam;1 ignorado pela ausência de captura histórica.
Incluem43 contratos do executável FL27. Pacote local recompilado como build51
em `release/0.2.0-local/FlAccess.zip`,97 arquivos no manifesto.

Instalado em `C:/Users/Diego/Documents/jogos/football life 2027/SiderAddons`.
Conferência final:31 módulos iguais à fonte;30 recursos e3DLLs iguais ao backup;
FlAccess.ini idêntico. sider.ini só ganhou reader_groups e reader_lists nas
posições previstas, preservando os outros módulos. Backup:
`local-backups/flaccess020-install-20261103-125459-052014`.

Gameplay19, Prism, DLLs, sons e preferências permanecem preservados. Fonte:
`C:/Users/Diego/git/diegomatos16/FLAccess/modules/FlAccess`.
Instalação usa backup e acrescenta os dois módulos no sider.ini, preservando os
demais mods. Sem publicação, commit, push ou tag. Audição e desempenho51 no jogo
ainda precisam do retorno do usuário; Diário, notícias, data e rolagem da
classificação não são encerrados por este relatório.
