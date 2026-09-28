# Revisão do mod e base de testes

## Escopo inspecionado

- Módulo principal `FLAccess.lua` e cópia ativa no `SiderAddons`.
- Módulo de gameplay reservado, runtime Prism, índices de texto PT/EN,
  extração/catalogação e gerador dos índices.
- Fontes alteradas do Sider (`sider.cpp`, `util.asm`), documentação, instalação
  e changelog. O código de terceiros em `reference/` e pacotes históricos em
  `release/` não são código mantido nesta revisão.

## Comando

Na raiz do jogo: `./FLAccess/tests/run-all.ps1`. Esse comando testa cópia
mantida e cópia ativa, exige hashes iguais para Lua e índices, executa sandbox
restrito por 120 quadros, confere os 12 prólogos de hook em `FL_2026.exe` e
executa testes Python da extração. Dependência: LuaJIT incluído no projeto e
Python 3 (`-PythonPath` se necessário).

## Cobertura automática

**Unidade:** limpeza de strings e marcadores de controle; papéis dos índices
PT/EN e opção de desligá-los; filtros de texto não interativo; reconhecimento
de instrução e botão; normalização de nomes e prefixo de registro; papel
diagnóstico; diferenças do painel Sider; formação; grupo de copa; seleção de
backend Prism; descompressão WESYS, offsets UTF-8, idioma, prioridade de papel
e saída determinística dos índices.

**Integração simulada:** mensagem capturada pela camada de interpretação,
temporização em `display_frame`, fila nativa e chamada do backend; botão
enfileirado depois da mensagem; abertura/alteração/fechamento de painel; opção
de tooltip pelo teclado; transição de contexto do Plano de jogo. A simulação
verifica lógica entre etapas, mas não substitui o jogo nem o Prism real.

**Regressão:** texto `Carregando a bola` não vira mensagem; mensagens paginadas
e mutação direta; duplicação de fala; fila antiga descartada no reset; repetição
de resets; foco de diálogo antigo; formação efetiva; prefixo de grupo; retorno
de Alterar formação; carregamento em sandbox sem funções proibidas; prólogos do
executável; cópias de desenvolvimento e instalação sincronizadas.

## Revisão de diálogos e grade da Champions

O `SiderAddons/sider.log` existente mostra `OK, item selecionado` antes de
`Os agrupamentos da Fase de grupos podem ser definidos livremente.` e outro
`OK` ao fim da fileira de times. O código permitia fala de foco com interrupção
durante um parágrafo e guardava só uma mensagem pendente. Prioridade modal
agora vale para todas as rotas de `speak`: diálogo pendente segura foco,
mudanças durante leitura são condensadas ao último anúncio e enviadas sem
interromper, e páginas rápidas conservam ordem. O `OK` residual da grade é
ignorado. A suíte reproduz sequência observada com backend simulado. Ainda
requer confirmação auditiva no jogo.

## Apresentações, títulos e navegação rápida

O catálogo marca o parágrafo `Há muitas escolhas na carreira de um jogador de
futebol...` como diálogo, mas o log não mostrava sua entrada na rota normal de
widgets. A captura pelo resolvedor agora usa o papel do catálogo para
parágrafos longos; modelos com `%s` também são reconhecidos. Títulos curtos
imperativos são tratados como título em vez de depender de tela específica.
O foco observado durante leitura deixou de ser marcado como já anunciado;
segurar a leitura não é cancelado ao navegar. O teste simulado cobre ida e
volta rápida na mesma linha, mas resposta e vínculo rótulo/valor precisam ser
confirmados no jogo real. O processo não estava em execução nesta revisão;
nenhuma janela do usuário foi tomada para teste.

## Problemas encontrados e correções

1. Papel `status` do catálogo passava à frente da exclusão explícita de
   `Carregando a bola`. Filtros de texto não interativo e splash agora têm
   prioridade sobre classificação do catálogo.
2. `context_reset` limpava estado da interface, mas deixava comandos de fala
   antigos na fila e a chave de deduplicação recente. Reset agora esvazia ambos.
3. `record_game_plan_input` chamava `reset_focus_reuse_state` como global antes
   da declaração local; A, B ou Escape podiam gerar erro. A rotina agora vive
   em `a11y` e todos os pontos de chamada usam essa referência.
4. Fonte e instalação ativa divergiam na limpeza da tabela de grupos ao trocar
   de tela. Ambas as transições relevantes agora limpam o estado e as duas
   cópias são idênticas.

## Limites

Não foi executado o jogo durante esta revisão. Testes de memória real, foco,
crash do Sider, saída NVDA/SAPI e experiência de uma pessoa cega seguem
pendentes. Plano de jogo, estádio, time visitante e combinações de controles
já constavam como áreas instáveis/parcialmente verificadas na documentação.
Consulte [MANUAL.pt-BR.md](MANUAL.pt-BR.md) para passos e resultados esperados.
O núcleo C++/ASM foi inspecionado e o binário foi verificado pelos prólogos;
não houve reconstrução do `sider.dll` ou teste de estabilidade em jogo.
Há risco residual no núcleo Sider: texto de painel acima de 4.095 caracteres
é truncado no cache de comparação e `wcscpy` copia o texto renderizado para um
buffer fixo sem limite explícito. Nenhum painel atual foi confirmado com esse
tamanho; o caso precisa de limite verificado e reconstrução do DLL antes de
ser considerado resolvido.
