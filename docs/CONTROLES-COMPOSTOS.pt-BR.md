# Controles compostos — investigação e dev 8, 14/10/2026

## Evidência da base atual

A dev 7 encontra eventos de foco nas áreas silenciosas. Falta de callback não
explica, sozinha, esses exemplos. A captura mostra o motor enviando o evento
para vários componentes do mesmo item e o resolvedor ficando ambíguo.

- Treinamento: pacote no quadro 13294 inclui 0x43a2fdf0 (text_item, Drible),
  0x5cf20860 (infoText_item, Resultado), 0x82ae8ab0 (infoText_value, 0).
  Os três compartilham o vínculo em +0x38 = 0x660e6970. A trace registra
  ambiguous-selection. A legenda principal e o status foram tratados como
  escolhas independentes.
- Configurações: pacote no quadro 15001 contém nove receptores. Entre os
  observados estão setName/Duração da partida, text/10 min. e abilityNumber/0.
  Os dois primeiros já têm relação label/value; o terceiro não é uma escolha.
  Os registros também retêm nomes de objetos destruídos/reutilizados, como uma
  antiga legenda de idioma. Uma legenda em cache não certifica o objeto atual.
- Nível da partida chegou a ser anunciado. Não faltam todas as strings nem toda
  comunicação com o NVDA. A captura foi usada para corrigir a decisão comum,
  não para cadastrar os nomes das telas ou traduzir por conta própria.

Capturas preservadas: tests/capture-dev7-2026-10-14-sider.log e
tests/capture-dev7-2026-10-14-focus-trace.log.

## Alterações gerais

1. Números avulsos e campos padIcon/abilityNumber deixam de concorrer como
   escolhas. Valores numéricos ligados a um controle continuam elegíveis,
   inclusive zero. A regra usa estrutura/relação, não a palavra da legenda.
2. No esquema de componente text_item/infoText_*, o texto principal prevalece
   sobre campos de informação quando há exatamente um text_item, vínculo de
   recurso idêntico e a mesma entrada de foco. Campos de outro recurso ou dois
   principais não são arbitrariamente colapsados. Dados auxiliares ficam no
   modelo; sua presença não assegura que cada um esteja no buffer de revisão.
3. O agrupamento de nome e valor admite o valor observado no modelo, mesmo que
   seja um número que não entrou na antiga tabela de foco. O zero não se perde.
4. Nome interno e vínculo atual são confrontados com a observação em cache.
   Se mudaram, o objeto perdeu aquela identidade: esquecer legenda e relações
   antigas, esperar observação nova. O vínculo de recurso não é tratado como
   prova de propriedade de janela ou de visibilidade.
5. Ambiguidades passam a registrar os candidatos, somente quando o conjunto
   muda, para distinguir novas famílias e falhas na captura de dados.

Os nomes dos slots vêm do jogo e descrevem um esquema compartilhado. Seu uso
para distinguir o campo principal é uma interpretação estrutural apoiada nesta
captura, não um papel de acessibilidade fornecido oficialmente pelo motor.
Não há condição por Treinamento/Champions, Drible, Resultado ou Duração da partida
no algoritmo de seleção. Esses textos aparecem somente nos testes/evidência.

## Testes e limites

174 testes Lua por cópia, nove Python, sandbox Sider por 120 quadros e 14
assinaturas passaram. Log: tests/compound-focus-suite.log. Os cinco casos novos
incluem os conjuntos de campos observados, informação de outro recurso que deve
permanecer ambígua, reaproveitamento de identidade e valor zero legítimo.
São reproduções dos dados relevantes em memória simulada, não execução da
captura completa nem prova audível do jogo.

Dev 8 instalada, versão base 0.1.7, sem hooks adicionais. Fonte e instalação
iguais; backup de segurança da dev 7 em backups/2026-10-14-compound-focus/FLAccess.lua.
Nenhuma cópia antiga foi usada para a investigação/correção. Nenhuma publicação.

Validação real da dev 8 permanece aberta. Verificar itens das áreas relatadas e
de outros menus durante uso habitual; conferir engine-focus-commit/unresolved
quando houver silêncio. Não declarar cobertura de todas as telas a partir
desses testes, nem fechar os relatos do usuário antes da validação real.
