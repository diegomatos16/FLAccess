# Estrutura do FLAccess

## Decisão de seleção — dev 20

Os produtores de foco, controle, lista e resposta entregam seus dados ao resultado
comum selection_result. A entrega e a revisão usam sua composição; a fila confere
nome/valor/contexto/dono/geração atuais antes de falar. Adaptadores anteriores
submetem seu foco pelo mesmo limite de validação, preservando extração aprovada.
Parágrafos e avisos são eventos próprios. Apresentação não implica aceitar entrada;
relações Task são lidas somente na família Window comprovada. Estado e limites:
[decisão comum](DECISAO-COMUM-DEV20-2026-10-19.pt-BR.md).

O projeto continua sendo distribuído como um único mod, mas possui componentes
independentes para impedir que leitura de menus e áudio de partida cresçam no
mesmo arquivo.

## Componentes

- `FLAccess.lua`: leitor de telas. Captura texto, foco, controles, diálogos e
  painéis do Sider; usa diretamente a API C nativa do Prism.
- `FLAccess-Prism/`: `prism.dll` e licenças. A DLL seleciona leitores
  compatíveis e usa SAPI quando nenhum estiver disponível.
- `FLAccess-text/`: índices UTF-8 compactos de textos em português e inglês.
  Cada entrada associa o texto exato do jogo a um papel semântico. O módulo usa
  essa informação antes das heurísticas e mantém foco/contexto como autoridade.
- `FLAccess_gameplay.lua`: componente reservado para acessibilidade durante a
  partida, como localização sonora da bola, jogador, gol e limites do campo.
  Na versão 0.1.5 ele não instala hooks nem produz áudio.

O Sider executa cada módulo Lua em ambiente isolado e não disponibiliza
`require`. Por isso, componentes Lua permanecem arquivos independentes dentro
do mesmo pacote. Isso também permite desativar recursos de jogabilidade sem
desativar leitor de menus. O componente de jogabilidade só será acrescentado
ao `sider.ini` quando tiver uma função utilizável.

## Regra para código futuro

O leitor agora mantém um modelo limitado de observações de widgets, separado
das decisões de foco e das funções de fala dentro do mesmo módulo compatível
com o sandbox. Campos estruturais são associados independentemente da ordem
de captura. Veja [leitor estrutural](LEITOR-ESTRUTURAL.pt-BR.md) para funcionamento,
testes, limites e reversão local.

- texto, foco, controles, idiomas e fala pertencem ao leitor de telas;
- posição, estado da partida e sons direcionais pertencem à jogabilidade;
- comunicação com NVDA, JAWS, outros leitores e SAPI pertence à integração Prism;
- estado compartilhado deve usar protocolo explícito, não variáveis globais
  entre módulos.
