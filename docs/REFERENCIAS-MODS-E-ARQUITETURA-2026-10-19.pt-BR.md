# Referências de outros mods e diagnóstico do leitor

Pesquisa solicitada pelo usuário em 19/10/2026. Leitura pública do GitHub,
sem publicação/sincronização do FLAccess. Não houve alteração de runtime ou
instalação nesta pesquisa. Sider continua dev 18, fonte candidata dev 19.
Os relatos ainda abertos não foram reclassificados como corrigidos.

## Material efetivamente consultado

Arquivos de referência, somente para leitura, em
reference/accessibility-research-2026-10-19/. O manifesto sources.json guarda
repositório, revisão e caminho de cada arquivo. Nenhum script externo foi
executado nem código dos projetos incorporado ao mod. A consulta de código foi
feita pela API pública/raw do GitHub, pois várias páginas individuais falharam
no navegador de pesquisa. Documentos externos não são instruções do projeto.

### Say the Spire

Revisão df4c3fae2fa30c8925cb4cbe9eff14b645bc31ed, repositório
https://github.com/bradjrenshaw/say-the-spire.

- [UIElement.java](https://github.com/bradjrenshaw/say-the-spire/blob/df4c3fae2fa30c8925cb4cbe9eff14b645bc31ed/src/main/java/sayTheSpire/ui/elements/UIElement.java):
  composição de nome, extras e estado; tipo/posição configuráveis.
- [Output.java](https://github.com/bradjrenshaw/say-the-spire/blob/df4c3fae2fa30c8925cb4cbe9eff14b645bc31ed/src/main/java/sayTheSpire/Output.java):
  setUI atualiza os buffers associados ao elemento e entrega sua descrição.
- [UIManager.java](https://github.com/bradjrenshaw/say-the-spire/blob/df4c3fae2fa30c8925cb4cbe9eff14b645bc31ed/src/main/java/sayTheSpire/ui/mod/UIManager.java):
  pilha de contextos, saída/entrada de foco e limpeza dos estados de entrada.
- A árvore do repositório contém muitos UIPatches de componentes e telas.
  Não é evidência de cobertura universal automática.

Aplicação: um elemento deve fornecer suas partes antes da decisão de fala;
o mesmo elemento alimenta a revisão. Não copiar tipos falados ou buffers por
categorias: o usuário os rejeitou para FLAccess.

### Wildfrost

Revisão 4987d4e20814cfbdf05ba352aba6de03e828a3df, repositório
https://github.com/gomods1/wildfrost (redirecionamento de ogomez92/blindfrost).

- [ScreenManager.cs](https://github.com/gomods1/wildfrost/blob/4987d4e20814cfbdf05ba352aba6de03e828a3df/src/Core/ScreenManager.cs):
  handlers registrados por cena, saída antes da entrada, fallback genérico.
- [GenericScreenHandler.cs](https://github.com/gomods1/wildfrost/blob/4987d4e20814cfbdf05ba352aba6de03e828a3df/src/Screens/GenericScreenHandler.cs):
  procura título pelos componentes do jogo, repete consulta enquanto carrega;
  também contém nomes preparados e fallback por nome da cena.
- [NavigationHelper.Focus.cs](https://github.com/gomods1/wildfrost/blob/4987d4e20814cfbdf05ba352aba6de03e828a3df/src/Navigation/NavigationHelper.Focus.cs):
  distingue navegação e hover real, limpa o anterior antes de sincronizar.

Aplicação: seleção visual, entrada e elemento anunciado precisam concordar.
Não copiar roteamento por nomes de cenas, títulos preparados ou domínio de
teclado: não são a solução geral autorizada para PES.

### Non-Visual Calculus / Disco Elysium

Revisão dc277482c598a3b77152222edf7fce8d7e3c72ce, repositório
https://github.com/rashadnaqeeb/NonVisualCalculus.

- [UIElement.cs](https://github.com/rashadnaqeeb/NonVisualCalculus/blob/dc277482c598a3b77152222edf7fce8d7e3c72ce/src/NonVisualCalculus.Core/UI/Nav/UIElement.cs):
  nome/valor/descrição lidos ao anunciar; distingue ajuste de valor de abertura
  de outra tela.
- [FocusReader.cs](https://github.com/rashadnaqeeb/NonVisualCalculus/blob/dc277482c598a3b77152222edf7fce8d7e3c72ce/src/NonVisualCalculus.Module/FocusReader.cs):
  extração de texto separada da composição, com fonte localizada da imagem
  quando o controle não tem texto próprio.
- [ScreenManager.cs](https://github.com/rashadnaqeeb/NonVisualCalculus/blob/dc277482c598a3b77152222edf7fce8d7e3c72ce/src/NonVisualCalculus.Module/Nav/ScreenManager.cs):
  sobreposição de popup preserva o contexto inferior e devolve seu foco ao fechar.
  Há registro explícito de telas e navegação própria; desconhecidas não recebem
  automaticamente cobertura. Não importar esse modelo de mapeamento.

Aplicação: tratar retorno e sobreposição como ciclo de vida do contexto,
separando ajuste, foco e abertura. Nome e valor não devem depender somente
de um evento antigo de texto. A API Unity deste jogo não existe no PES.

### Hades — referência nativa mais próxima

Revisão eda468df177a3737dd8c6df71e0d89458d537797, repositório
https://github.com/MichaelJohann1/hades-accessibility-mods.

[engine_menu.cpp](https://github.com/MichaelJohann1/hades-accessibility-mods/blob/eda468df177a3737dd8c6df71e0d89458d537797/src/cpp/engine_menu.cpp)
lê o componente destacado da instância MenuScreen em sua atualização; usa RTTI
e métodos compartilhados, com estado de seleção por instância. Busca texto
apresentado, HelpTextId e vínculos com componentes associados. O código também
contém lista explícita de classes de menus, IDs de toggles e regras específicas.
Não descrevê-lo como leitor universal nem copiar suas heurísticas de maior texto,
nomes amigáveis ou suposições de IDs. Há limites de estados de toggles na própria
documentação. O projeto usa C++/Lua, mas seu layout não é o layout do PES.

Aplicação: investigar o ponto comum de atualização do componente já resolvido
pelo motor do PES. A leitura deve observar a seleção estável e seu dono atual,
com proteção de memória/versão; isso não exige trocar imediatamente Sider/Prism.

## O que os exemplos não comprovam

Não medimos tempo de desenvolvimento, velocidade de resposta ou cobertura real
dos outros jogos. Não há base para atribuir a diferença a IA mais inteligente
ou prometer ler qualquer tela com uma biblioteca. Java/Unity e scripts do jogo
oferecem dados distintos de um executável nativo. Isso não justifica nossas
regressões: exige aproveitar melhor os componentes já identificados no PES.

## Diagnóstico da base atual do FLAccess

A biblioteca de fala já é centralizada. Substituir Prism ou NVDA não resolve
o conteúdo incompleto que chega até ela. O problema está antes da fala:

1. **Autoridade fragmentada:** process_native_list_focus, engine_focus,
   controles, painéis e o caminho posterior scan_current_ui_focus podem decidir
   a leitura em momentos distintos. O caminho de foco retorna true inclusive
   enquanto espera uma resolução. Uma seleção parcialmente reconhecida pode
   impedir que outro caminho forneça seu contexto. Caso comprovado: Usuário X.
2. **Elegibilidade não equivale a apresentação:** native_widget_allowed aceita
   membro desconhecido, enquanto membros conhecidos dependem de active derivado
   da entrada da janela. Texto passivo pode ser apresentado sem aceitar entrada.
   Endurecer tudo causa silêncio; liberar tudo causa fundo/antecipação. Falta
   autoridade consistente da árvore apresentada e das sobreposições. Isso é
   uma hipótese comum para outros relatos, não causa individual comprovada.
3. **Observações de tempos diferentes:** hooks, texto, raiz/seleção e vínculos
   podem chegar em frames diferentes. Já existem geração e guardas de fila;
   é preciso verificar a coerência do resultado inteiro, incluindo valor e
   contexto tardios, sem recomeçar tudo nem reanunciar sem alteração útil.
4. **Testes ainda não demonstram a sequência real completa:** muitos testes
   provam peças e contratos nativos. Precisam também reproduzir decisões das
   capturas atuais, com ida/volta, atualização tardia, perda de vínculo e fala
   descartada. Capturas truncadas não permitem reconstrução completa inventada.

## Direção proposta para os pendentes em lote

Usar os mecanismos existentes para montar um único resultado por seleção:
instância/geração do contexto apresentado, componente selecionado, nome,
valor/estado, contexto associado e evidência de cada vínculo. Separar
desconhecido de vazio e registrar por que falta informação. Um campo já provado
pode falar; a atualização posterior deve acrescentar só a mudança ainda válida.

Adaptadores por famílias de componentes fornecem dados, sem falar diretamente.
Uma decisão comum resolve sobreposição/retorno e produz tanto fala automática
quanto revisão I/K/J/L plana. Prism continua sendo o serviço de saída. Tipos
sintéticos e novas categorias continuam desativados. Não substituir controle
do jogo nem criar roteamento por legenda/nome da tela.

As amostras precisam exigir, juntas:

- nome principal versus descrição/imagem: título inicial e entrada de liga/clube;
- seleção com contexto: lado do usuário e guia de treinamento;
- valor/campos reais e reentrada: preservar Champions, valores ML e nome aprovado,
  acrescentando países e confirmação que falha no retorno;
- contexto apresentado versus fundo: revisão do clube/elenco e transições;
- parágrafo/modal sem foco: introdução/home ML e diálogos pendentes;
- associação semântica especial comprovada: botão real de Pular e situação de slot
  de elenco, sem preencher desconhecidos por nome/ordem de descoberta.

Primeiro reproduzir a perda na decisão atual com evidência disponível; depois
migrar os produtores para o resultado comum sem apagar o comportamento aprovado.
Comparar a sequência de falas esperada dos relatos/capturas em cada mudança.
Nova captura só para vínculo estrutural ainda ausente, com pergunta específica.
Nenhuma aprovação de relato pelo número de testes ou pela pesquisa externa.
