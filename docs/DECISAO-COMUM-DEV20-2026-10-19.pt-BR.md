# Decisão comum de leitura — entrega local dev 20

Implementação autorizada após a pesquisa comparativa de outros mods. Trabalho
local, sem publicação/sincronização. Base 0.1.7; build instalada 0.1.7 dev 20.
A candidata dev 19 foi incorporada nesta entrega, não instalada separadamente.

## O que mudou no mecanismo

### Um resultado antes da fala

selection_result reúne componente, nome, valor, contexto de guia/atribuição,
dono, geração, origens e campos ainda desconhecidos. Valor desconhecido é nil;
zero continua sendo um valor válido. selection_result_signature identifica esse
conjunto. deliver_selection_result atualiza a seleção de revisão, decide a
duplicação e entrega à fila comum; selection_result_allowed valida novamente
o conjunto antes de o Prism recebê-lo.

Foco do motor, controles, listas e respostas de diálogo usam esse caminho.
Os produtores de foco dos adaptadores anteriores também passaram por
offer_adapter_selection, preservando a extração existente. Parágrafos, avisos,
teclado e ajuda continuam sendo eventos próprios; não fingem ser seleções.
Não foi apagado todo adaptador de domínio nem provada cobertura universal.

Estado queued não significa delivered. Descarte/falha permite tentar novamente;
volta ao mesmo item e reentrada em nova geração não ficam presas à deduplicação.
Só uma seleção ainda válida conserva sua fala pendente. O getter de texto atual
também é conferido, mesmo se o evento de atualização ainda não chegou ao modelo.
O valor/página/contexto antigos não podem pegar carona no nome ainda selecionado.

### Guia e listas

A lista anteriormente retornava assim que seu registro estava committed. Isso
impedia reavaliar contexto associado quando a guia mudava sem novo callback de
lista ou novo texto. O registro continua sendo autoridade de seleção, mas a
decisão comum consulta novamente o contexto. O índice/registro nativo de guia
continua sendo a fonte; sem catálogo de nomes de guias ou telas.

### Apresentação separada de entrada

WindowImpl+90 é consultado junto da raiz de navegação +98 e das raízes pertencentes
à janela. Janelas relacionadas podem ser encontradas pelos vínculos Task pai,
filho e próximo irmão. Só a família com os dois métodos de ciclo de vida
comprovados é aceita; Node+38 não é interpretado como Task+38.

Uma janela ancestral sem entrada pode fornecer texto de contexto quando existe
descendente com entrada e a raiz ancestral está apresentada. Isso não a promove
a dona de seleção. Cada texto ainda precisa do estado nativo apresentado.
Janelas desativadas sem esse vínculo continuam excluídas. Caminhos, ciclos e
quantidade de janelas/irmãos/ancestrais são limitados. Isso amplia descoberta de
componentes aninhados, inclusive as famílias já reconhecidas de guia e elenco.
Não prova que todas elas foram encontradas na execução real do usuário.

### Atribuição de lado

Foi removido o algoritmo que atribuía Em casa/Neutro/Fora pela ordem de
descoberta de três widgets Usuário. A família do componente é reconhecida pelos
consumidores nativos c68fd0/c67970, sem usar título ou legenda de tela.
c67970 grava a coluna em +a4; c68e40 usa grupo +94 e coluna +a4 para chegar ao
texto do usuário. O novo leitor exige que esse caminho contenha o texto
efetivamente selecionado. c67ad0 comprova coluna 1 como não atribuída, coluna 0
como lado 1 e coluna 2 como lado 2.

Em casa/Fora vêm dos campos text_home/text_away apresentados do mesmo componente
ou pai Task comprovado. Neutro/Neutral é o anúncio do estado não atribuído,
solicitado pelo usuário, não uma alegação de que existe esse texto desenhado.
Índice inválido, métodos diferentes, falta de legenda, caminho divergente ou
legendas contraditórias não autorizam inventar um lado. Esse vínculo nativo
passou nos testes internos, ainda não foi ouvido na instalação real.

### Revisão e comandos

I/K/J/L permanecem numa sequência plana. A seleção usa o mesmo resultado da fala,
com valor atualizado ao revisar. Um clube committed com painel de jogadores
ainda não comprovado devolve apenas seu nome; não cai na varredura que expunha
clubes laterais. Cabeçalhos associados são aceitos por estrutura/dono da lista.
Seleção de outro componente não herda a revisão do clube anterior.

GuideBar agora usa os sete pares efetivamente consultados pela apresentação do
jogo: tipo 19, índices 0..6 para ícones e 7..13 para legendas, em ordem da árvore.
Os pares de templates da inicialização foram descartados como fonte de ligação.
A tradução dos marcadores j/k já comprovada segue a tabela nativa atual.
Não transformar placeholders numéricos em nomes de botões.

## Lote de relatos e estado honesto

Todos os relatos abaixo foram considerados na implementação/validação dos
mecanismos comuns. Nenhuma falha real foi encerrada pelos testes internos.

| Relatos | Mecanismo trabalhado nesta entrega | Limite ainda existente |
| --- | --- | --- |
| 1 título inicial; 18 entrada de liga/clube | raízes de apresentação, texto atrasado, primeira seleção/reentrada e lista comum | o vínculo do título inicial com texto/imagem ainda não está comprovado; não há título literal inserido |
| 3 guia de treinamento | lista reavalia contexto; descoberta de janela relacionada; índice/registro nativo | falta audição real da guia no componente encontrado |
| 9 revisão do clube/elenco | mesmo resultado da seleção, painel associado e bloqueio de clubes laterais | falta confirmação de que o painel real é vinculado e atualizado na instalação |
| 10 países | descoberta de componentes aninhados, consulta de texto atual e seleção comum | captura atual não comprova o vínculo nativo específico que falta na lista de países |
| 11 confirmar após voltar da edição | geração, reentrada e descarte sem consumir anúncio | falta teste real do retorno; OK da segunda etapa continua aprovado |
| 14 Pular | pares consumidos pela apresentação, código e fonte de ícones atuais | nome físico do comando precisa ser ouvido nas cenas reais |
| 15 introdução/home ML | texto de contexto sem entrada, raiz completa e descarte do contexto anterior | faltam vínculos apresentados da introdução/home na captura atual; não declarar resolvido |
| 16 situação do elenco | descoberta dos componentes filhos e preservação dos cartões/slots/limite real da regra | sem slot/limite comprovados não anunciar situação; falta audição real |
| 19 lado do usuário | família de atribuição, grupo/coluna reais e legendas do componente | ainda sem confirmação real de descoberta/associação na sessão do usuário |

Preservados: Champions e nome do treinador aprovados na dev 18; câmera/estádio;
valores ML e confirmação da segunda etapa; aprovações anteriores dos itens
5/6/7/8/12/17 e retirada de tipos sintéticos. A aprovação anterior não demonstra
ausência de regressão nesta nova build. Inserção de caracteres segue silenciosa;
exclusão/cursor e restrição do analógico direito não foram redesenhados.

## Validação realizada

- 291 verificações Lua passaram na fonte e na cópia instalada.
- 27 testes Python de componentes/contratos/captura e 6 de extração passaram.
- Sandbox do Sider: 120 frames, Prism inicializado; 15 assinaturas do executável;
  175 locais no módulo. Nenhum hook novo foi acrescentado.
- Fonte e instalação têm hash SHA256 idêntico:
  8A20F67A2C6A328F7DCC8CD877DA17B55521062062D5B64946635D75A5681705.
- Suíte completa: tests/unified-selection-suite.log. Investigação de diferenças
  e testes intermediários: tests/unified-selection-*.log/diff.txt.

Os testes novos incluem valor zero/tardio; valor alterado antes de o modelo
receber evento; dois produtores da mesma seleção; ida/volta e reentrada;
descarte e nova tentativa; guia mudando sem callback de lista; ancestral passivo
sem assumir foco; janela filha tipada versus objeto de outro tipo; coluna de
atribuição visitada em ordem 2/0/1, parada sem repetição e legenda sem vínculo.

Dez pacotes de nome/valor da captura real dev 18 foram preservados em
tests/fixtures/observed-fields-dev18.lua. Incluem câmera, estádio, treinador,
nacionalidade e roupa. tools/export_selection_replay.py faz a exportação e o
teste de proveniência confere SHA256 e existência dos pacotes na captura.
Eles reproduzem **composição com dados reais**, fornecendo o vínculo observado;
não reconstroem a árvore completa, não provam descoberta e não substituem audição.
Captura original: SHA256 b22a7f9abae6ce1518aeda187e30228e1914e57fa8241eaccc750ce3d7412d70.

## Instalação e evidência seguinte

Jogo fechado ao instalar. Backup de segurança local:
local-backups/dev18-before-common-selection.lua. Não foi usado como caminho de
investigação. Fonte e Sider conferidos pela suíte completa após a instalação.
As capturas dev 18 foram preservadas. A próxima sessão é capturada uma vez,
automaticamente. Novos registros RESULT e ASSIGNMENT mostram a decisão inteira,
estado de entrega e grupo/coluna nativos; WINDOW mantém tipo, raiz e parentesco.

Não solicitar nova passagem ampla por tudo como prova de resolução. Analisar os
novos vínculos ao receber uso real; se algo faltar, pedir somente a informação
estrutural específica. Não repetir a promessa de leitor universal nem fechar
pendentes pela quantidade de testes.
