# Leitura por contexto e buffer de consulta

Versão local experimental: 0.1.6, 8 de outubro de 2026. Fonte e módulo instalado foram atualizados localmente. Nenhum envio para GitHub.

## Para testar

Reinicie jogo e Sider para carregar o módulo. Comece pelas perguntas da Liga Master: ouvir pergunta, percorrer respostas, confirmar e chegar à pergunta seguinte. Depois teste configurações, confirmação de saída dos grupos e retorno ao menu principal.

O esperado: pergunta antes da resposta inicial; cada mudança lê a resposta atual; próxima pergunta pode reutilizar o mesmo botão sem ficar muda; menu e ajuda do fundo não disputam leitura. Quando os sinais não permitem identificar a seleção, o módulo registra a falha, sem escolher uma resposta ao acaso.

## Consulta manual

Com jogo em primeiro plano e painel do Sider fechado:

- I: texto anterior.
- K: próximo texto.
- J: primeiro texto.
- L: repetir texto atual.

Uma única sequência, sem categorias: título, pergunta ou diálogo, seleção atual, atributos disponíveis e ajuda vinculada ao item. Textos idênticos não se repetem na lista. A lista acompanha o contexto atual; não guarda o histórico de todas as telas nem inclui texto apenas encontrado na memória.

Atributos usam os mesmos comandos. Ctrl+setas e F6–F10 foram retirados. Analógico direito para cima/baixo percorre a mesma lista somente no painel de atributos reconhecido do Plano de jogo, sem pergunta ativa. Não foi liberado nos demais menus; telas onde o jogo usa esse analógico devem ficar excluídas. O antigo comando horizontal de leitura da escalação foi retirado por falta de confirmação de ausência de conflito.

Primeiro testar: I/K/J/L não devem mudar o cursor do jogo nas telas utilizadas. O mod observa essas teclas; não bloqueia possíveis associações nativas. Ctrl+setas foi descartado após o relato de conflito.

Trocar tela ou abrir pergunta descarta conteúdo anterior. Mudar de campo descarta ajuda de outro campo. O jogador pode consultar ajuda mesmo com sua leitura automática desativada, quando essa ajuda foi capturada pelo hook de texto da interface.

## Implementação

O contexto de leitura tem geração própria, tipo, título/enunciado, seleção, ajuda, cursor e origem da decisão. Perguntas reconhecidas pelo catálogo ou pela captura de parágrafo interrogativo usam leitor comum de respostas: resolução de seleção em +0x104, estabilidade de quatro quadros e comparação com widgets presentes antes da pergunta. Texto atualizado no fundo, por si só, não vira resposta.

Confirmar ou cancelar libera o contexto. Uma confirmação pode conservar por até 120 quadros o vínculo de respostas previamente aceitas, somente para nova pergunta no mesmo widget de enunciado, sem mudança da geração do modelo. Isso permite perguntas consecutivas reutilizarem uma resposta e seu bit de foco. Mudança de tela, outro enunciado proprietário ou identidade de widget reciclada invalida esse vínculo. Observações e vínculos são limitados pelo modelo de até 300 widgets; informação de atributos tem limite de 80 entradas.

Diálogos Sim/Não continuam usando adaptador existente, mas alimentam o mesmo buffer. Controles, sliders, listas nativas, foco genérico, seleção de lado e cabeçalhos do Plano de jogo também alimentam seleção aceita. Durante uma pergunta, ajuda atrasada, cabeçalhos de jogadores e listas do fundo não têm prioridade. Primeiro anúncio de resposta pode ser enfileirado após enunciado; mudanças posteriores acompanham navegação.

Widgets title/text_title com caption desconhecido não reinicializam um menu funcionando. Após fronteira de contexto já reconhecida, um caption desconhecido aguarda seleção aceita antes de ser anunciado como título. O nome interno title sozinho não comprova uma nova tela: pode pertencer ao painel de música.

## Verificação e limites

107 casos Lua por cópia, nove testes Python, sandbox Sider por 120 quadros e 12 prologues existentes passaram. Dezoito casos novos cobrem perguntas arbitrárias, resposta reutilizada, contexto antigo, ambiguidade, buffer, valores, limpeza de widget e títulos desconhecidos. Resultado salvo em tests/context-buffer-suite.log.

O teste no jogo ainda é necessário. Não foi comprovado um gerenciador global de foco nem proprietário/visibilidade de todos os painéis; +0x38 continua candidato diagnóstico. Nenhum hook nativo novo ou varredura global de memória foi acrescentado. Perguntas cuja resposta não usa os sinais de foco já conhecidos podem continuar sem leitura; isso exige captura da tela real, não uma promessa de cobertura universal. O conteúdo da lista é deliberadamente restrito enquanto pertencimento dos demais textos ao painel não estiver provado.

Logs reading-context e dialog-selection-unresolved mostram abertura do contexto e motivo de seleção não resolvida. MCP NVDA é ferramenta de teste, não requisito para jogar. Se usado, consultar durante percurso e salvar trechos incrementais para evitar expiração da sessão.

## Backup

Versão anterior preservada em backups/2026-10-08-context-buffer/FLAccess.lua. Com jogo e Sider fechados, restaurar esse arquivo para modules/FLAccess.lua e SiderAddons/modules/FLAccess.lua. O backup é anterior à versão local 0.1.6 e conserva as correções da rodada anterior.

Backup da alteração de atalhos: backups/2026-10-08-flat-buffer/FLAccess.lua. Suíte atual: tests/letter-review-suite.log.

## Relato da tela de treinador

O log local registrou "Nome do treinador, seletor, Luis Figo", seguido de "Insira os detalhes do treinador.", "Avançar, botão selecionado" e "OK, item selecionado". Nesse caminho, o código convertia literalmente OK em Avançar; a conversão foi removida. O candidato OK também tinha atividade antiga. A captura do botão pendente agora exige foco primário e sinais posteriores à abertura da mensagem, ou um widget/texto novo.

A proteção após confirmação deixa de bloquear globalmente um nome de item por 30 segundos. Conserva identidade/texto dos objetos antigos e libera objeto novo, identidade reciclada, mudança de texto ou nova ativação do foco primário. A retenção antiga continua bloqueada enquanto não há evidência nova.

Essas correções não comprovam qual painel está por cima. A navegação posterior pelos campos do treinador não aparece no trecho disponível; o silêncio relatado ainda precisa ser reproduzido e correlacionado com os sinais do jogo. Próximo teste: introdução com OK, confirmação, nome do treinador, demais campos e retorno. Registrar se um item do fundo disputa leitura mesmo quando os dois painéis continuam vivos. Não adicionar uma exceção específica por nome de tela como substituto do vínculo ao painel ativo.

Backup desta rodada: backups/2026-10-08-letter-review/FLAccess.lua.

Investigação posterior de foco: retorno ao mesmo controle invalida a deduplicação da visita anterior; bancos secundários antigos deixam de herdar seleção quando o foco primário mais recente desaparece. Captura automática FLAccess-focus-trace.log auxilia identificar o sinal faltante; detalhes e roteiro em TESTES-LEITURA-PENDENCIAS.pt-BR.md. Suíte atual: 111 casos Lua, tests/focus-lifetime-suite.log. Reconhecimento global de painel continua pendente.

Rodada posterior: foco primário simultâneo no rótulo e valor do mesmo controle é resolvido como seleção única, com base na relação já capturada. Legendas text/ícones padIcon do mesmo grupo observado não recebem seleção secundária; um botão com foco primário continua elegível. Evidência, limites e roteiro em TESTES-LEITURA-PENDENCIAS.pt-BR.md. Suíte atual: 115 casos Lua, tests/semantic-focus-suite.log; resultado no jogo pendente.

Rodada seguinte: question/eventMsg e respostas text do mesmo grupo observado recebem escopo interativo. Pergunta ganha prefixo, respostas são anunciadas na seleção após navegação; campos do fundo ficam bloqueados nesse escopo. Confirmar não libera imediatamente o menu atrás do diálogo. Limpeza de ícone não rearma leitura de campo parado. 118 casos Lua por cópia, tests/question-panel-suite.log. Avançar e a passagem entre configurações e abertura do diálogo continuam pendentes; captura ampliada dos grupos em FLAccess-focus-trace.log. Detalhes em TESTES-LEITURA-PENDENCIAS.pt-BR.md.
