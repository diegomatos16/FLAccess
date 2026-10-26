# Revisão do jogador — dev 25 local, 25/10/2026

## Decisões do usuário

- Titular, reserva e não relacionado: somente ao navegar entre jogadores,
  junto do número/nome. Não entram nas etapas de revisão.
- K avança; I volta. Analógico direito para baixo/cima equivale a K/I no painel
  do jogador em foco. Primeiro K repete número/nome; próximo lê posição
  principal; depois secundárias existentes; depois posição no campo.
- Secundárias completas e parciais, identificadas explicitamente como
  “adaptação completa” e “adaptação parcial”. Principal excluída dessa lista.
- Fora do campo: “Não está no campo.” Dado ausente não comprova ausência.

## Aprovação audível preservada

Usuário confirmou na dev 24 as opções na entrada do plano de jogo e os nomes
em Editar posição. Essas duas regressões estão encerradas por audição real.
Titular/reserva/não relacionado continuava ausente: item 16 segue aberto até
confirmação real desta entrega. Nenhum outro relato foi encerrado pela suíte.

## Evidência e mecanismo

Captura atual dev 24 preservada em tests/capture-dev24-components.log e
tests/capture-dev24-sider.log. Há cartões com IDs reais e painéis de jogadores,
mas não há registros PLAYER_PANEL nem IDs no cache de atributos. Os limites
capturados pelo hook aparecem ausentes. A falta desse cache bloqueava o
caminho antigo de situação; nomes já funcionavam independentemente dele.

O consumidor nativo 910490 escolhe uma das duas variantes do painel pelo grupo
da apresentação. A tabela nativa em +34a2048 fornece os nomes dos grupos;
8e1e90 copia o descritor de slot/lado. O novo leitor segue esse descritor,
ordem atual do elenco e objeto real do jogador. Valida vínculo do controlador,
painel, lado, Task, nome apresentado e ID. Não depende do cache de atributos.
Não há seleção por nome de tela, nova regra por legenda ou novo hook.

Posição principal vem da propriedade nativa 0, getter 14c66c0: bits altos de
objeto+4. Aptidões vêm das propriedades 1–13, campos compactados +1c/+20:
0 ausente, 1 parcial, 2 completa; valor inválido não é pronunciado como posição.
Posição no campo é outra fonte: formação atual, tática e fase; getter 14c61d0.
Slot fora dos onze comprova “Não está no campo”, mesmo quando o limite entre
reserva e não relacionado ainda não é conhecido.

Situação automática reaproveita os cartões apresentados e a regra real.
Além do retorno já capturado pelo hook, lê os caminhos comprovados de 8e9210:
modo 4 e configuração padrão do jogo. Competições com regra consultada no banco
de dados ainda dependem da captura válida do retorno nativo. Nesses casos,
sem limite comprovado, não inventa reserva/não relacionado. Portanto a nova
leitura não garante cobertura universal desse estado.

Revisão mantém sequência própria por jogador e contexto. Trocar jogador,
reentrar ou mudar ID reinicia no nome. A fala em espera revalida identidade e
valor antes da entrega, inclusive jogadores com nomes iguais. Analógico retido
não repete cada quadro; fora desse painel preserva a revisão anterior.

## Verificação e instalação

- 321 verificações Lua em cada cópia, 38 Python (32 contratos/estrutura e
  6 extração/textos); suíte completa aprovada.
- Sandbox Sider: 120 quadros, 15 eventos; 15 assinaturas nativas; 175 locais.
- Testados: principal diferente da função no campo, secundárias de ambos os
  níveis, ausência de secundárias, rotação da sequência, troca de jogador,
  ID alterado com nome igual, valor atrasado, diálogo, controle e situação
  sem cache. São testes internos, não prova de audição ou descoberta no jogo.
- Fonte e instalada iguais, SHA256
  CCC8F6389AE790F54D63D79A756C7A60528EBE52A2F099F02C8D66F2AEEF6342.
- Log: tests/dev25-full-suite.log. Backup da instalada dev 24:
  local-backups/2026-10-25-before-dev25/FLAccess.lua.

Captura de uma sessão rearmada, com PLAYER_DATA para ID/slot/aptidões/função
e regra/limite, além de PLAYER_PANEL/SLOT. Busca comprovar o vínculo novo e o
limite ainda ausente no uso real; não pede outra passagem ampla.
Dev 25 instalada; revisão e situação ainda sem confirmação audível.
