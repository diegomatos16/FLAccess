# Visualização unificada — 0.1.9 dev27 local

## Decisões permanentes do usuário

“Visualização” é o mesmo sistema de revisão por I/K e analógico direito, até
decisão futura. I volta; K avança; direito cima/baixo equivale a I/K. J vai ao
primeiro dado; L repete. Sequência única, sem categorias. Não mudar para o
analógico esquerdo ou Ctrl+setas. Preservar o uso do jogo onde houver conflito.

Y/Triângulo abre o painel pelo próprio jogo. A revisão prioriza esse painel
sobre o jogador ao fundo. Um passo anuncia um rótulo com seu valor: “Altura:
1,70 metros”, “Peso: 70 quilos”, “Passe rasteiro: 90”. Altura e peso primeiro.
Não despejar rótulos e depois números soltos.

Usuário autorizou retirar “posição principal” sem origem independente comprovada
e usar estilo de jogo, mantendo posição no campo como dado separado. “Ala
produtivo” é estilo, não posição. Fora do painel, revisão do jogador percorre
número/nome, estilo e posição no campo ou Não está no campo. Secundárias
completas/parciais continuam retiradas. Situação titular/reserva/não relacionado
fica somente na navegação, anunciada ao entrar ou mudar de grupo.

## Retorno real da dev26 e evidências

Preservados tests/capture-dev26-components.log e tests/capture-dev26-sider.log.
Usuário relatou nomes repetidos parado, painel desorganizado, guias do treino
silenciosas e versão inicial ausente, com apenas Dados editados falado.

- Barcola: playStyle apresentou “Ala produtivo”. height_item/weight_item estavam
  separados dos valores 182/73; outra coluna apresentava “-”. Um vínculo
  provisório ligava Passe alto a Ala produtivo. A nova revisão não usa esse
  vínculo nem proximidade/ordem de escrita para associar dados.
- Nomes: identidade alternava com e sem panel-roster no mesmo cursor. A nova
  deduplicação retém apenas o último token comprovado, sem conservar atributos
  ou conceder autoridade a uma situação desconhecida.
- Treino: 22 PAGE_STATE e nenhum PAGE. Registro e índice existem mesmo sem
  exercício selecionável. Nomes reais capturados: Básico, Intermediário,
  Avançado e Perito; não substituir por nomes presumidos.
- Entrada: dp_value apresentou “Versão 26.2.03    edit file 2.00” sem cursor;
  copyRight apresentou “Versão do jogo: 2.2”. Dados editados foi falado depois.

Igualdade entre principal e função no campo não prova, por si só, erro ou uma
posição original diferente. Essa origem independente não foi comprovada nesta
rodada. O rótulo foi retirado por decisão do usuário, sem substituir por palpite.

## Implementação comum

- Pares _item/_value, inclusive índices, exigem mesmo proprietário e raiz
  nativos, texto atual e um único valor preenchido. Coluna vazia não compete;
  dois valores preenchidos para o mesmo rótulo permanecem ambíguos. Conversões
  de cm/kg exigem unidade explícita e campo correspondente.
- Y captura ID, slot, lado e descritor, sem manter ponteiro do objeto. Leitura
  resolve novamente ordem, ID e nome. Atributos individuais usam os campos
  compactados já suportados, com plausibilidade e revalidação na entrega.
- Revisão estruturada precede o jogador ao fundo. Retiradas a síntese aproximada
  de seis categorias e a revisão autorizada somente por cache/timer. Valores
  sem associação não recebem números ou descrição gráfica inventados.
- Estilo segue 911650, 8e1f40/14c0300, propriedade 3b (bits 11–15 de +1c),
  tabela de códigos +2979080 e IDs +27d3500. Texto é o resolvido pelo jogo
  para esse ID e idioma. Código zero indica ausência de estilo; texto ainda
  não resolvido fica indisponível. Posição não serve de substituta.
- Guia usa registro ativo mesmo sem texto selecionável no conteúdo. Não repete
  anúncio separado quando a seleção já inclui a guia. Troca invalida fala antiga;
  janelas concorrentes ambíguas não geram escolha arbitrária.
- Informação estática _value autossuficiente, sem rótulo parceiro, pode ser
  anunciada em apresentação atual sem cursor/seleção. Não vira opção de menu;
  entrega revalida texto e proprietário. Esse mecanismo cobre a versão capturada.

## Verificação e limites

336 verificações Lua por cópia; 43 Python (6 textos + 37 projeto). Sandbox
Sider: 120 quadros/15 eventos; 15 assinaturas; 175 locais. Suíte aprovada em
tests/dev27-final-suite.log. Fonte e Sider iguais, SHA256:
5A8A909A9A02DCB6A035CC14BE4E94D4B02AD090B9E0FEDF3A5CB778A5CC5354.
Backup: local-backups/2026-10-26-before-dev27/FLAccess.lua.

Testes cobrem unidades, pares com coluna vazia/ambígua, I/K e direito, analógico
retido, ID alterado, valor atualizado antes da fala, estilo separado de posição
e idioma, guia sem seleção, versão estática e token opcional instável. Contratos
do executável comprovam getters/tabelas; não comprovam audição real.

Dev27 instalada, sem audição nesta rodada. Relatos reais continuam abertos até
confirmação. Estilo pode ficar indisponível antes de o jogo resolver seu texto.
Campos gráficos sem vínculo não são inventados. Posição original e secundárias
seguem pendentes. Aprovações anteriores preservadas. Nada publicado no GitHub.

Captura estruturada da próxima sessão serve para conferir identidade estável,
PAGE/índice/legenda e associação de rótulos/valores. Navegação normal, sem
pausas fixas ou nova passagem ampla. Captura bruta continua só no diagnóstico.
