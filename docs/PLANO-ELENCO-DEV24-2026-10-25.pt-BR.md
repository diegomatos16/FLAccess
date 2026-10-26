# Plano de jogo e nomes do elenco — dev 24, 25/10/2026

## Relato e entrega

Usuário relata duas regressões: primeira tela do plano de jogo deixou de ler
opções; entrada em Escalação/Editar posição não lê nomes dos jogadores.
Confirmou que navega pelo controle. Dev 24 instalada localmente com jogo/Sider
fechados; fonte e instalação iguais. Base 0.1.7 preservada. Sem publicação.

Atualização real de 25/10: usuário confirmou funcionando as opções na primeira
tela do plano de jogo e os nomes em Editar posição. Essas duas regressões foram
aprovadas por audição. Situação titular/reserva/não relacionado continua ausente,
segundo novo retorno; item 16 aberto. Demais aprovações/pendências preservadas.
Nova revisão detalhada do jogador por I/K e analógico direito em alinhamento,
registrada no NOTEBOOK. Não pedir outra passagem ampla.

## Evidência disponível e limites

A captura estruturada encontrada era build 23, iniciada em 22/10/2026 às
04:27:07 UTC, e terminou ainda no título: 63 amostras, última no frame 5347.
Não contém estas duas telas. Preservada em tests/capture-dev23-components.log.
O marcador estava consumed. Isso não equivale a uma captura do relato atual.

Trace disponível de 23/10 foi preservado em
 tests/capture-2026-10-23-focus-trace.log. Registra entradas do plano de jogo e
Editar posição, textos playerName atuais e motivos no-selection/legacy-adapter.
O sider.log de 25/10 foi preservado separadamente em
 tests/capture-2026-10-25-sider.log: inicialização dev 23, sem conteúdo suficiente
para demonstrar o foco nestas telas. Não juntar endereços de sessões distintas.

A captura dev 21 já preservada fornece a relação estrutural: no pacote 178,
MainMenu tem cursor de ícone sem texto, mas legenda text diretamente no grupo
pai; no pacote 200, SelectPositionEdit tem cursor sem texto e o painel irmão
ParameterPlayerInfo apresenta playerName, ambos sob o mesmo Task pai.
Esses pacotes orientam o padrão; não são teste real da dev 24.

## Causa e implementação

O leitor comum consultava apenas textos descendentes do objeto selecionado.
Quando a seleção é um ícone, a legenda pode ser um irmão direto no grupo.
Na seleção do elenco, o nome fica no painel de informação associado ao
controlador, e não dentro do cartão selecionado. Portanto os textos renderizados
podiam existir sem se tornarem candidatos do cursor comum. O caminho sem decisão
podia ainda manter o adaptador antigo sem autoridade para uma leitura nova.

Dev 24 estabelece dois vínculos de componentes:

- Cursor com ícone sem texto: aceita a única legenda textual ativa, renderizada,
  diretamente pertencente ao mesmo grupo. Recusa grupo com duas legendas,
  placeholders, números isolados e padIcon. Não enumera legendas por ordem nem
  mantém tabela de opções por tela. O consumidor nativo 8f0366..8f03f2 confirma
  o grupo indexado e a escrita da legenda compartilhada text.
- Controlador de seleção/painel: reconhece a família SelectBase pelos métodos
  nativos compartilhados em vtable+100/+1a0 e ParameterPlayerInfo pelo tipo
  comprovado. Exige mesmo Task pai, mesmo lado, cursor real sem texto e um único
  playerName atual no painel ativo. O nome passa a ser candidato do cursor.
  A família inclui outros seletores de jogador, sem condição por título de tela.

Nomes não dependem de existir registro de atributos ou classificação do elenco.
A classificação da dev 23 continua opcional e exige suas próprias provas.
Eventos propagados nos demais campos do painel não viram escolhas concorrentes.

Identidade inclui janela, raiz, grupo, objeto selecionado, índice e vínculo do
painel. Duas opções com legenda igual continuam sendo movimentos distintos.
Ao entregar, a decisão comum revalida o vínculo; cursor nativo, Impl/raiz e
estado da janela também são consultados novamente. Mudança de jogador/opção,
fechamento ou atualização de texto invalidam fala antiga. Mantidos I/K/J/L,
fonte de fala única e regras de descarte da base atual.

Não foi liberada leitura de fundo como substituto para seleção desconhecida.
Não foram adicionados hooks, mapeamentos por legenda ou posições fixas de tela.
Adaptadores históricos não foram removidos nem considerados cobertura universal.

## Validação

313 verificações Lua por cópia, 35 Python (29 componentes/contratos e 6 extração),
sandbox de 120 frames, 15 assinaturas e 175 locais passaram. Log completo:
 tests/dev24-cursor-caption-suite.log. Contratos do executável e disassembly em
 tests/dev24-*-native.txt, tests/dev24-player-controller-types.txt e
 tests/dev24-native-contracts.log.

Testes novos cobrem legenda fora do ícone, legendas iguais em índices diferentes,
duas legendas ambíguas, texto oculto, cursor que muda antes da nova captura,
nome sem callback e sem ID/atributos em cache, troca de jogador, reentrada,
equipe distinta, outro Task, controlador desconhecido e evento de fundo no painel.
Envio ao backend Prism é simulado. Não substitui audição nem demonstra ausência
de regressões ou desempenho no jogo.

Fonte/Sider SHA256:
61EF527EBC25F9178619C60321F6A0B8DDA8770A48687EEB1303A4BF4707AF0B.

## Continuidade

Captura automática de uma sessão rearmada depois de preservar a build 23.
Novo registro CAPTION_SELECTION guarda widget e identidade do vínculo.
WINDOW continua registrando grupo/índice/status; PLAYER_PANEL/SLOT/ID da dev 23
preservados. Analisador aceita o novo registro sem inferir visibilidade ou situação.
Próxima utilização permite conferir especificamente legenda/cursor/painel.

Backup exclusivamente de segurança:
local-backups/dev23-before-cursor-captions-2026-10-25.lua. Para desfazer esta
entrega, restaurar esse arquivo em modules/FLAccess.lua e na cópia instalada
SiderAddons/modules/FLAccess.lua, com jogo e Sider fechados. Não usar backup
como caminho de investigação.
