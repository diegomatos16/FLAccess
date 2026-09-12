# Estrutura do FLAccess

O projeto continua sendo distribuído como um único mod, mas possui componentes
independentes para impedir que leitura de menus e áudio de partida cresçam no
mesmo arquivo.

## Componentes

- `FLAccess.lua`: leitor de telas. Captura texto, foco, controles, diálogos e
  painéis do Sider; usa diretamente a API C nativa do Prism.
- `FLAccess-Prism/`: `prism.dll` e licenças. A DLL seleciona leitores
  compatíveis e usa SAPI quando nenhum estiver disponível.
- `FLAccess_gameplay.lua`: componente reservado para acessibilidade durante a
  partida, como localização sonora da bola, jogador, gol e limites do campo.
  Na versão 0.1.5 ele não instala hooks nem produz áudio.

O Sider executa cada módulo Lua em ambiente isolado e não disponibiliza
`require`. Por isso, componentes Lua permanecem arquivos independentes dentro
do mesmo pacote. Isso também permite desativar recursos de jogabilidade sem
desativar leitor de menus. O componente de jogabilidade só será acrescentado
ao `sider.ini` quando tiver uma função utilizável.

## Regra para código futuro

- texto, foco, controles, idiomas e fala pertencem ao leitor de telas;
- posição, estado da partida e sons direcionais pertencem à jogabilidade;
- comunicação com NVDA, JAWS, outros leitores e SAPI pertence à integração Prism;
- estado compartilhado deve usar protocolo explícito, não variáveis globais
  entre módulos.
