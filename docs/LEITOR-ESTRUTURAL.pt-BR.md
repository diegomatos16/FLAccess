# Leitor estrutural: implementação local

Data: 2026-10-08. Fonte: `FLAccess/modules/FLAccess.lua`.
Instalação: `SiderAddons/modules/FLAccess.lua`. Nenhum checkout Git ou serviço
remoto foi modificado. MCP NVDA permanece adiado.

## Comportamento implementado

O leitor mantém até 300 observações de widgets e um índice de nomes internos.
Cada observação tem endereço, nome, texto, papel estrutural, geração,
identidade e quadro de atualização. Captura de texto não prova visibilidade;
o modelo não inventa uma árvore de acessibilidade do jogo.

Pares `campo_item` e `campo_value` são reconhecidos sem nomes de tela, IDs de
localização ou rótulos cadastrados. O valor pode chegar antes do rótulo e
campos diferentes podem se atualizar intercalados. O controle fala nome,
tipo e valor quando recebe foco; alteração de valor no controle ativo fala
apenas o novo valor. Capturar um campo sem foco não o anuncia.

Nomes duplicados tornam o par ambíguo. O leitor descarta o vínculo anterior,
impede que o fallback por ordem de chegada reivindique esse valor e espera
evidência suficiente. `_value` não vira rótulo de outro controle. Nomes longos
em `_item`, até 160 bytes, permanecem elegíveis; apenas tamanho da legenda
não os transforma em parágrafos modais. Papéis explícitos de diálogo no
catálogo continuam prioritários.

Nos menus comuns que usam o campo de foco verificado `+0x104`, múltiplos
candidatos são comparados pela ativação do bit de seleção. Um redesenho de
texto não passa à frente de uma seleção mais recente. Ativações simultâneas
permanecem ambíguas em vez de escolher pelo texto mais recente ou pela ordem
da tabela. Os adaptadores de Game Plan, pré-partida, copa e diálogos conservam
suas decisões específicas.

Campos esvaziados, nomes internos alterados e observações expulsas do limite
perdem vínculos e estado de foco. Transições já reconhecidas pelo mod iniciam
uma geração nova. Títulos estruturais `title` e `text_title` também delimitam
superfícies: observações de quadros anteriores são descartadas, e o lote do
mesmo quadro é reconstruído em duas passagens para preservar campos que
chegam antes do título. Esse lote ainda pode conter textos de fundo; não
equivale a comprovar pertencimento ao painel.

A fala aceita identidade do controle para distinguir dois controles com
legenda igual. O limite de deduplicação de texto continua valendo para as
rotas anteriores. Logs de foco acrescentam motivo e identidade da decisão.
Quando o diagnóstico está ligado, foco estrutural ambíguo pode produzir
snapshot limitado, sem despejo contínuo.

## Verificação

A suíte `FLAccess/tests/run-all.ps1` verifica ambas as cópias e seus hashes,
79 casos comportamentais Lua por cópia, nove testes Python, carregamento e
120 quadros em sandbox Sider, além dos 12 prólogos existentes do executável.
Nenhum hook novo foi instalado.

Os 17 casos adicionados cobrem ordem de captura, campos desconhecidos,
ambiguidade, descarte de valor antigo, endereço reaproveitado, texto vazio,
limite do modelo, foco contra redesenho, legenda igual em controles distintos,
transição, retorno, rótulo longo, preservação do tipo/faixa de slider nativo
e fluxo completo de nome/valor/fala.

Na execução desta implementação, o temporário padrão do Python teve problema
de permissão no sandbox. A suíte foi executada com `TMP` e `TEMP` apontando
para `FLAccess/.test-temp` dentro do workspace. Essa alteração valeu somente
para o processo de teste, sem alterar configurações do usuário.

Testes offline não certificam visibilidade real, correção do foco em todas as
telas ou áudio ouvido pelo jogador. O jogo não estava em execução durante a
implementação. Próxima validação local: configurações com seletores, regras
de torneio, retorno entre telas, navegação rápida e Game Plan; ler os logs
após essa navegação. Não é necessário habilitar MCP NVDA para isso.

## Limites ainda abertos

- O gerenciador global de foco e o proprietário real dos widgets ainda não
  foram comprovados. `+0x38` permanece apenas candidato diagnóstico.
- Não se pode eliminar todos os adaptadores de Game Plan ou aplicar `+0x104`
  indiscriminadamente a qualquer estrutura.
- Telas sem título estrutural nem transição já reconhecida conservam as
  limitações do acompanhamento anterior. Widgets de fundo redesenhados no
  mesmo quadro do título podem entrar no lote; ambiguidade não é resolvida
  assumindo visibilidade.
- Essa base amplia leitura automática de estruturas conhecidas; ainda não
  representa cobertura universal ou autonomia completa do jogo.

## Backup e reversão

A versão ativa anterior, idêntica à fonte antes das mudanças, foi preservada
em `FLAccess/backups/2026-10-08-structural-reader/FLAccess.lua`. SHA-256:
`B77FB63F157E51D624D1EC5966BDDE3DC7D09257CB5B5801C1063ACCD08EDFE8`.

Para reverter o runtime, com jogo e Sider fechados, copiar esse arquivo para
`SiderAddons/modules/FLAccess.lua` e `FLAccess/modules/FLAccess.lua`. Os testes
novos dependem das funções estruturais e não servem para validar o runtime
antigo. A documentação, plano e backup não são carregados pelo jogo; sua
remoção não altera o runtime.
