# Sondagem estrutural da interface

## Objetivo e limite

Encontrar sinais reutilizáveis do jogo para distinguir texto de apresentação,
título, diálogo, botão, seletor e valor antes de alterar a fala. O levantamento
atual é **observacional**: não atribui papéis novos nem muda a ordem da leitura.
Isso evita transformar uma correlação vista em poucas telas em regra para o jogo
inteiro.

## O que foi verificado

- Os três diagnósticos já existentes registram 185 eventos de foco. É possível
  recuperar um nome interno de 145 deles, lendo a string MSVC situada em
  `widget + 0x18`. O modo de diagnóstico agora registra esse nome diretamente.
- O campo em `widget + 0x38` contém um ponteiro candidato a relação entre
  widgets. Alguns eventos de uma mesma tela compartilham esse valor: por
  exemplo, `ok_text` e `teamName` em 13 eventos. Ainda **não foi demonstrado**
  que seja o pai da árvore visual; pode ser outro objeto compartilhado.
- O vtable RVA `0x27b5260` aparece em 31 eventos classificados pela heurística
  atual como botão, 55 como seletor e 65 como foco desconhecido. Classe/vtable
  não basta para determinar o papel acessível.
- Os nomes `btnH_str`, `description_0`, `teamName` e `text` aparecem associados
  a mais de um papel *heurístico*. O nome sozinho também não basta. Esses
  números descrevem os logs disponíveis, não todos os widgets do jogo.
- Os textos de `Data/dt20_bra_x64.cpk` (`bra/string/all.str`) incluem exemplos
  como “Escolha sua aparência”, “Nome do treinador” e “Número de usuários”.
  Os IDs numéricos observados em tempo de execução não foram encontrados como
  inteiros de 32 bits no conteúdo descomprimido; seu mapeamento ainda é aberto.

## Captura atual

Com o modo de diagnóstico ativado pelo painel do mod, cada evento de foco
registra `widget_internal_name`, `widget_relation_candidate`, vtable, texto,
contexto recente, campos de foco, possíveis links e até 40 widgets recentes.
O inventário recente agora inclui nome interno e relação candidata de cada
widget legível. Os campos novos são somente de diagnóstico; o modo permanece
desligado por padrão. Veja o procedimento de ativação no [README](README.pt-BR.md).

Para comparar logs antigos e novos sem abrir o jogo:

```powershell
& 'C:\Users\Diego\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  FLAccess/tools/analyze_widget_structure.py `
  SiderAddons/FLAccess-diagnostic.log `
  SiderAddons/FLAccess-diagnostic1.log `
  'SiderAddons/transferpatch FLAccess-diagnostic.log'
```

O analisador imprime JSON, não altera os arquivos e conserva a classificação
existente apenas para expor contradições. Endereços de ponteiro só devem ser
comparados **dentro da mesma execução**: ASLR e realocação podem mudá-los.

## Critério para a próxima regra de fala

Capturar, em sessões curtas, pelo menos: (1) aviso com texto e botão Avançar;
(2) tela com título, campos e valores; (3) seletor/lista da Champions e uma
tela diferente com widgets homônimos. Registrar a ordem de entrada, mudança de
foco e botão confirmado. Só promover um sinal a classificador se ele preservar
o papel nos exemplos positivos e negativos; preferir uma combinação de relação
entre widgets, foco e evento de transição a uma palavra ou vtable isolada.
Depois, criar casos de repetição offline para diálogo-primeiro, título uma vez,
valor do controle, navegação rápida e retorno ao foco anterior.

## Captura de 22/09/2026

O usuário percorreu Liga Master e Champions com o diagnóstico ativado. O novo
log contém 153 eventos de foco. A gravação de fala em `sider.log` confirmou:

- “Escolha sua aparência” foi falado como título; “Nome do treinador”,
  “Nacional./Região” e “Roupa em jogos” foram falados com os valores.
- Dois parágrafos da apresentação da carreira saíram na ordem errada:
  parágrafo, “Avançar”, segundo parágrafo, “Avançar”. A fila agora deixa o
  botão para depois do último parágrafo e o anuncia uma vez. Há teste offline
  para essa sequência.
- Na fase de grupos, `groupName` (“Grupo A” etc.) apareceu antes do OK da
  grade e antes do texto explicativo. A grade agora pode ser reconhecida por
  esse sinal estrutural e pelo formato do cabeçalho, suprimindo esse OK desde
  a entrada; o anúncio do parágrafo continua ativo. Há teste offline.
- “Número de usuários” teve eventos de foco no diagnóstico, mas não apareceu
  como controle na sequência de fala próxima. Mensagens de ajuda foram
  enfileiradas ao redor da navegação. **A causa completa do silêncio ainda
  não está provada; esta captura não autoriza dizer que foi corrigido.**

A classificação `groupName` é restrita à grade A–H observada. Ela não torna
outros nomes internos (`text`, `teamName`, `btnH_str`) classificadores gerais.
Nenhum teste automatizado substitui a próxima validação de fala dentro do jogo.

## Regressão de navegação rápida relatada após a captura

O `sider.log` posterior mostrou que os hooks recebiam ligas e clubes da Liga
Master, mas a fala desses focos ficava retida enquanto avisos e ajudas ocupavam
a fila modal. Em volume, descrições de controles catalogadas como `instruction`
entravam como diálogo, antes de nome/tipo/valor. Em pré-partida, a mensagem
“A partida começará...” era capturada repetidamente em submenus. Na seleção de
lado, “Conecte o controle.” podia virar rótulo espúrio de “Usuário 1”.

Correções offline: ajudas reconhecidas são retiradas da fila modal e ficam
vinculadas ao respectivo controle; a confirmação explícita libera a estimativa
de leitura de um aviso concluído, mas não de um tutorial paginado; o aviso de
prontidão não é reenfileirado enquanto a pré-partida permanece ativa; frases
de ajuda terminadas em pontuação não viram rótulos inferidos; a mesma posição
de lado não é anunciada repetidamente sem mudança. A classificação do catálogo
sozinho **não** foi usada para descartar `tooltip-or-description`: um parágrafo
real da Liga Master tem esse rótulo. A validação dentro do jogo permanece
pendente, sobretudo para navegação rápida e ordem controle→tooltip.

## Ajustes gerais após o relato de 24/09/2026

O `sider.log` mostrou opções do menu principal enviadas duas vezes (primeiro
como fala imediata, depois pela tentativa atrasada), o título “Escolha sua
aparência” seguido de foco que podia cortá-lo e a pergunta “Que tal se
focarmos em vencer o campeonato?” interrompida por “Concordo.”. O diagnóstico
estrutural anterior mostrou títulos em widgets `title`/`text_title`, inclusive
“Opções de técnico”, “Regras” e “Lista de jogadores”. As strings extraídas
contêm `<Pular>%s`, mas não comprovam que o hook atual recebe esse marcador
durante a cena.

O runtime agora evita a segunda tentativa do menu principal quando a primeira
fala já saiu; identifica títulos por esses nomes internos; preserva o título
enfileirado quando aparece um diálogo; classifica “Concordo.” como botão;
descarta focos da tela anterior ao confirmar uma transição; solicita ao Prism
interromper somente a fala do NVDA no primeiro movimento após diálogo/título;
e anuncia o comando Options se o marcador de pular for observado. Há testes
offline para os comportamentos de título, diálogo, NVDA e marcador. O teste
real de leitura automática do marcador e das transições ainda está pendente.

O Plano de jogo continua **não resolvido**: a captura disponível mostra o
aviso de configuração básica e textos de jogadores, mas não os itens do menu
“Táticas”/“Escalação/Editar posição”. A próxima captura deve registrar entrada
no Plano de jogo, deslocamento por três opções (incluindo essas duas), volta e
fechamento do jogo com diagnóstico ligado. Sem os eventos estruturais desses
itens, não é seguro inferir a origem do foco nem anunciar que a tela funciona.

## Nova navegação de 24/09/2026

O `sider.log` atualizado mostrou fala para “Escalação/Editar posição”,
“Alterar formação”, “Instruções ofensivas” e “Instruções defensivas”. Mostrou
também “Instruções avançadas, seletor, Ajuda”, associação incorreta de valor.
O arquivo `FLAccess-diagnostic.log` não foi atualizado nessa sessão; portanto
não há ainda prova estrutural nova para os widgets do Plano de jogo. O runtime
agora limpa as relações de controles ao entrar nele e não usa o pareamento
genérico de valores durante essa tela.

Na tela Football Life, o bloqueio de foco após anunciar o cartão principal
durava 45 quadros. A captura estrutural anterior já mostrava “Copa” e “Liga”
focados em `0x104`; o bloqueio caiu para quatro quadros. Nas regras de torneio,
os nomes internos `groupStage_item`/`groupStage_value` e equivalentes permitem
associar rótulo e valor por campo, sem depender da ordem de renderização. O
teste offline impede que `third_value` ou uma competição da lista vire valor de
“Fase de grupos”. Esses ajustes ainda precisam de confirmação no jogo.

## Diagnóstico ativo de 24/09/2026

O novo `FLAccess-diagnostic.log` confirmou a seleção `Usar` no aviso de
configuração básica, a passagem pelo menu tático e uma seleção de jogador em
`Escalação/Editar posição`. O `sider.log` mostrou um `OK` antigo aparecendo
entre “Configurações táticas básicas” e “Padrão”; o diagnóstico identificou
esse OK como um widget ainda focado desde a etapa anterior. Ele agora é
ignorado enquanto o contexto é de configurações táticas.

Na volta para a pré-partida, um widget antigo “Escalação/Editar posição” ainda
era redesenhado e reativava o leitor do Plano de jogo. A reentrada quando a
pré-partida já está ativa agora exige confirmação explícita do item “Plano de
jogo”. Fora do Plano de jogo, o mesmo widget “Informações” em `0x100` foi
anunciado seis vezes após um `context-reset`, sem troca de texto ou foco. A
pausa entre atualizações deixou de apagar o histórico de foco; reutilização
real de widget com texto diferente ainda o invalida. Testes offline cobrem
essas duas decisões, mas a fala precisa de nova verificação no jogo.

## Tela após o aviso de configuração básica

O usuário confirmou que o aviso é lido, mas a tela seguinte fica muda. A
captura mais recente registra a leitura de “Usar” e navegação lateral, porém
não registra seleção de comandos da tela seguinte. A resolução de foco do
Menu de configuração básica exigia ativação do bit de foco nos últimos 120
quadros, mesmo quando o widget continuava recebendo texto atualizado. Agora
um comando conhecido e recém-renderizado também é aceito. Confirmar “Usar” ou
“Não usar” encerra o estado do diálogo e descarta seu foco herdado. Se ainda
não houver comando identificável, o diagnóstico registra
`unresolved-game-plan` com inventário da tela, sem inventar uma opção. Os
testes offline passam; resta verificar a fala na tela real após reiniciar o
jogo e percorrer o menu.

Na nova captura, a primeira entrada no menu produziu apenas título e textos
de rodapé (como “Ajuda”) no hook de texto; seis movimentos laterais foram
registrados sem um item selecionado correspondente. Após abrir uma opção e
voltar, alguns comandos passaram a aparecer e foram lidos. Isso explica a
intermitência: o foco de um comando nem sempre é um widget de texto nessa
tela. O diagnóstico avançado agora registra `game-plan-menu-probe` três
quadros após cada movimento, incluindo widgets recém-renderizados e campos
da estrutura ligada ao título. A intenção é localizar um índice de seleção
estável antes de implementar uma leitura por posição, como a tela Em casa/Fora.
Ainda não há mapeamento confiável do índice para nomes de opções.

A captura seguinte resolveu a ambiguidade sem índice: nos sete movimentos
iniciais, o **mesmo** widget interno `text` trocou entre “Plano de jogo normal”,
“Escalação/Editar posição” e “Configurações táticas básicas”, três ou quatro
quadros depois de cada entrada. O foco genérico não o escolhia. O runtime agora
lê esse widget atualizado diretamente no Menu de configuração básica, usa o
nome observado para a confirmação seguinte e mantém o leitor de foco anterior
nas telas internas. Há teste offline para duas mudanças consecutivas do mesmo
widget; a validação auditiva no jogo ainda é necessária.
