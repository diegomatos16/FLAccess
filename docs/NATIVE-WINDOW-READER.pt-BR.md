# Leitor estrutural de janelas — versão local 0.1.7

Implementado em 08/10/2026. Resultado audível no jogo ainda não validado.

## Como funciona

O leitor consulta a instância de `WindowManager` guardada no RVA `0x36f9c10`.
A função `0xe71570` cria essa instância via `0xe710b0` e grava o ponteiro nessa
variável. A assinatura do getter é conferida antes de habilitar a consulta.
Não foram instalados novos hooks nem chamadas funções do jogo.

O gerenciador mantém oito listas de registros de janela, em `+8 + slot*24`.
Cada lista tem início/fim/capacidade; cada registro ocupa 16 bytes e começa
pelo ponteiro de janela. São consultadas também as oito referências atuais,
em `+0xc8 + slot*16`, com prioridade da posição em `+0xd0 + slot*16`.
Precisamos das listas completas porque janelas antigas deixam as referências
atuais, mas podem continuar registradas e manter textos com cursorOver.

Na janela, `+0x88` aponta para a implementação; `impl+9`, bit 0, é o estado
consultado por `0xe3dbc0` e alterado por `0xe41600`. O gerenciador desativa
esse estado nas janelas que cedem autoridade. `impl+0x98` aponta para a raiz
de elementos, utilizada pelas funções de busca da janela.

A árvore segue listas de filhos em `+0x170/+0x178` apenas nos tipos reconhecidos
que compartilham `NodeBasicNodeBase`: NodeRoot, NodeChoice, NodeWindow,
NodePage e o próprio tipo base. RTTI confirma herança com objeto base em
offset zero. Somente objetos NodeRectText recebem associação de texto.
Campos internos baixos também entram na captura de investigação.

Quando existe NodeCursor validado na raiz em `+0x190`, seus campos `+0x88`,
`+0x90` e `+0x94` permitem duas buscas na lista de filhos, reproduzindo o
caminho de `0xe72960`. O texto ou subárvore resultante é usado como seleção
primária somente quando seus textos também pertencem à árvore da janela
habilitada. Sem confirmação desse vínculo, continua o leitor anterior.

## Comportamento e limites

- Texto comprovadamente pertencente somente a janela desativada não compete
  pela seleção. Captura permanece preservada para a volta à janela.
- Elemento compartilhado continua elegível se algum proprietário está habilitado.
- Mudança dos proprietários habilitados reinicia a deduplicação do foco.
- Diálogo cuja mensagem pertence a janela comprovadamente desativada perde
  autoridade; a espera de leitura antiga também termina.
- Mensagens pendentes conhecidas como fundo são descartadas antes de falar.
- Estrutura desconhecida, versão incompatível ou nenhum texto reconhecido em
  janela habilitada não provoca bloqueio global. Esses caminhos ainda usam os
  leitores existentes e podem conservar problemas anteriores.
- Travessia limitada a 600 nós por raiz, 256 filhos por contêiner e 32 janelas.
  Listas inválidas não são percorridas. Árvores são reavaliadas a cada seis
  frames; estado das janelas e índices do cursor, a cada frame.
- I/K/J/L e analógico direito mantêm o comportamento combinado anteriormente.
  O buffer continua uma sequência única. Avançar gráfico sem texto ainda não
  tem uma legenda inventada pelo mod.

Os logs `native-windows` mostram identidade, raiz, prioridade da posição e
estado habilitado. `native-cursor` registra mudanças de textos selecionados,
limitado a 300 alterações por inicialização. Esses sinais precisam aparecer
na passagem real antes de declarar cobertura das telas.

## Verificação

129 casos Lua por cópia do módulo, nove casos Python, inicialização no sandbox
Sider por 120 frames e validação dos 12 hooks existentes passaram.
Log: `tests/native-window-suite.log`.

Casos novos: janela antiga ausente da referência atual, retorno sem novo setter
de texto, texto compartilhado, registro incompleto, construção de janela,
ciclo de filhos, índice inválido, árvore ativa desconhecida, fechamento de
diálogo e seleção via cursor mesmo quando o texto não altera cursorOver.
O teste de fala compara seleção atual e item antigo, incluindo retorno.
Esses testes usam memória simulada; não certificam execução dentro do jogo.

Backup anterior: `backups/2026-10-08-native-window/FLAccess.lua`.
Módulo mantido e instalado atualizados juntos.

## Próxima passagem curta

Reiniciar o jogo para carregar 0.1.7. Entrar em configurações, mover dois itens,
voltar; na Master Liga, navegar pelos detalhes do treinador, passar por Avançar
e seguir à pergunta. Percorrer respostas, revisitar uma e voltar quando possível.
O teste verifica se a mesma estrutura funciona entre telas e se o fundo fica
excluído. A captura é automática; MCP não é necessário.

Na análise seguinte, conferir primeiro `native-window-reader=true`, depois os
registros de janela e `native-cursor`. Ausência de associação de texto é um
limite de estrutura a investigar, não prova de que o menu esteja funcionando.
