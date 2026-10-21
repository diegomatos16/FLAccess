# Continuidade — fala adiada com vínculo / dev 21

## Estado conferido antes de continuar

Fonte e instalação eram dev 20 idênticas. Jogo fechado, captura ainda armed.
O arquivo de componentes disponível continua sendo build 18, 7.156.416 bytes;
não surgiu sessão nova da dev 20. Não atribuir aos logs antigos um teste desta
entrega nem marcar relatos reais como corrigidos. Os pendentes da matriz
DECISAO-COMUM-DEV20-2026-10-19.pt-BR.md continuam abertos.

## Falha comum reproduzida

A fila normal da dev 20 validava selection_result, mas a espera de uma fala de
menu durante um parágrafo guardava somente deferred_modal_announcement, um texto.
Ao terminar a espera, display_frame chamava speak com esse texto sem o componente,
valor, dono ou geração originais. Portanto a informação saía da decisão comum e
voltava como literal sem origem. Uma seleção adiada podia entregar um valor antigo
mesmo quando a validação da fila principal rejeitaria o mesmo conteúdo.

Um teste do caminho real display_frame/fila/saída Prism simulada reproduziu isso
antes da correção: campo muda de 6 para 10 durante a espera; ao liberar, chega
"Campo sem catálogo de tela, 6" ao backend. Evidência:
tests/deferred-origin-before.log. Não é teste audível no jogo; comprova a falha
no mecanismo de adiamento do módulo atual, sem consultar builds antigas.

## Correção geral

defer_speech preserva identidade, componente/origem, dono, geração e seleção.
Quando a solicitação veio da decisão comum, mantém também selection_result e
o modo de leitura do valor. O estado deferred é diferente de queued/delivered:
não consome o anúncio como se já tivesse sido entregue.

drain_deferred_speech aguarda a liberação do parágrafo/título e valida novamente
o pacote. Mudança de valor/texto, dono, seleção ou objeto reaproveitado descarta
a solicitação antiga. A seleção ainda atual volta pelo mesmo caminho comum,
incluindo as evidências na fila, sem interromper a fala anterior. Reset de
contexto também limpa texto e metadados pendentes juntos.

Não há condição por título/nome de tela, novo texto de jogo, botão presumido,
tipo falado ou categoria de revisão. A mudança vale para qualquer produtor que
aguarde esse bloqueio, incluindo controles e listas já atendidos pelo leitor.
Isso corrige uma via de fala antiga; não prova que todos os relatos reais de
texto de fundo tenham essa única causa.

## Validação e instalação

Quatro testes novos cobrem valor antigo descartado e valor atual entregue;
seleção válida aguardando e falando uma vez; mudança de dono antes de reset;
objeto reutilizado e limpeza na troca de contexto. A suíte anterior, inclusive
os dez pacotes de composição provenientes da captura real, permanece passando.

- 295 verificações Lua por cópia; 27 Python de componentes/contratos/captura
  e 6 de extração.
- Sandbox Sider 120 frames; 15 assinaturas; 175 locais; nenhum hook novo.
- Suíte completa: tests/deferred-origin-suite.log. Comparação atual da alteração:
  tests/deferred-origin-diff.txt. Instalação com jogo fechado, após conferência
  do hash instalado; backup somente de segurança:
  local-backups/dev20-before-deferred-origin.lua.
- Dev 21 instalada; SHA256 fonte/Sider:
  1DDDA0B0B3DB0EBE89AC28572AEE86EDB8E5D171E40D40DC2EAA855BB057FB77.

Captura permanece armed para uma sessão automática, agora da dev 21. Não pedir
outra passagem ampla. Título inicial, países, introdução/home ML e os demais
vínculos continuam nos estados documentados; a próxima evidência de execução
deve ser analisada com versão, sessão e registros estruturais corretos.
