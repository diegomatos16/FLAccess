# Scanner de acessibilidade do PES / Football Life

Versão: **0.1.4**  
Data do pacote: **29 de agosto de 2026**

## Objetivo

Este projeto pesquisa acessibilidade de menus sem OCR para o SP Football Life 2026, baseado no PES 2021. Ele captura textos e sinais de foco diretamente das estruturas internas do jogo, usando um módulo Lua do Sider, e os envia ao NVDA por meio do Prism. Se nenhum leitor compatível estiver ativo, o Prism tenta usar o Microsoft SAPI.

A versão 0.1.4 é experimental. Ela torna partes dos menus falantes, incluindo a seleção correta de ligas e clubes, mas ainda não oferece acessibilidade completa às partidas.

## Instalação do pacote pronto

Pré-requisitos:

- SP Football Life 2026 com o executável compatível `FL_2026.exe`;
- Sider funcional;
- Windows x64 com o runtime do .NET 8;
- NVDA recomendado, embora o bridge possa selecionar outro backend oferecido pelo Prism.

Procedimento:

1. Feche o jogo e o Sider.
2. Faça backup da pasta `SiderAddons`.
3. Copie o conteúdo da pasta `SiderAddons` do pacote para a `SiderAddons` da instalação do jogo.
4. Acrescente ao bloco `[sider]` de `SiderAddons/sider.ini`:

```ini
lua.module = "pes_a11y_menu_string_probe.lua"
```

5. Inicie o jogo pelo fluxo normal do Sider e mantenha o NVDA aberto.

O bridge é iniciado automaticamente depois que o jogo começa a renderizar. Não é necessário abrir um terminal nem executar `start-pes-a11y.cmd` manualmente. O script permanece apenas como ferramenta de diagnóstico.

## O que foi confirmado

- carregamento automático pelo Sider;
- inicialização e encerramento automáticos do bridge junto com o jogo;
- fala pelo NVDA usando Prism;
- fallback SAPI implementado;
- captura interna de strings UTF-8, sem OCR;
- leitura do menu principal e de seus tooltips no fluxo testado;
- leitura de rótulos, valores e mudanças laterais em sliders de áudio;
- leitura de várias listas e telas de configurações que usam widgets conhecidos;
- leitura parcial de opções e valores nos ajustes do controle e nas configurações gerais;
- anúncio apenas do novo valor em mudanças laterais reconhecidas;
- leitura de tooltips após uma pequena pausa em telas compatíveis;
- leitura de algumas caixas de diálogo `Sim`/`Não`;
- leitura nativa e sincronizada da liga realmente selecionada;
- leitura nativa do clube realmente selecionado, incluindo nomes padrão e nomes alternativos/modificados;
- seleção de ligas e clubes confirmada na Premier League e no Brasileirão;
- limpeza do arquivo de fala ao iniciar e redução de anúncios repetidos ou pertencentes à tela anterior.

## Cobertura experimental e limitações

Os testes mais recentes mostraram que a leitura ainda pode deixar de acompanhar o foco ao entrar ou voltar de uma tela. Em especial:

- o primeiro submenu depois do menu principal pode ficar silencioso;
- a tela `Bem-vindo ao Football Life`, com modos como amistoso, liga, copa e cooperativo, não é confiável em todas as entradas;
- a seleção horizontal `Em casa`, `Neutro` e `Fora` funcionou no fluxo testado, mas combinações com vários controles ainda precisam de cobertura mais ampla;
- a leitura nativa de ligas e clubes foi validada no fluxo de amistoso testado; outros modos ainda precisam de testes completos;
- a seleção do time visitante ainda precisa ser retestada com o novo leitor nativo de clubes;
- itens da tela pré-partida ainda não têm cobertura estável;
- alguns menus de configurações leem apenas a tela seguinte ou apenas valores, sem o rótulo;
- idiomas, câmeras, velocidade da partida e diálogos usam implementações diferentes e têm cobertura parcial;
- objetos de telas anteriores podem continuar vivos na memória, causando atraso ou anúncio incorreto apesar das proteções existentes;
- os endereços internos são específicos da versão estudada de `FL_2026.exe`;
- jogador controlado, bola, direção do campo e demais informações de gameplay ainda não foram implementados.

## Arquitetura

```text
FL_2026.exe
  -> hooks nativos instalados pelo módulo Lua do Sider
  -> associação entre strings, widgets, valores e foco
  -> SiderAddons/pes_a11y_speech.txt
  -> bridge .NET/Prism
  -> NVDA, outro leitor compatível ou SAPI
```

O módulo espera 120 quadros de `display_frame` antes de abrir o bridge. Isso evita o loader lock observado quando um processo externo era iniciado durante `init`. O bridge verifica o arquivo de passagem a cada 5 ms, interrompe a fala anterior durante navegação rápida e termina quando o processo do jogo termina.

## Estrutura do código

- `modules/pes_a11y_menu_string_probe.lua`: módulo principal do Sider;
- `prism-bridge/Program.cs`: bridge de fala;
- `prism-bridge/PesA11yPrismBridge.csproj`: projeto .NET 8;
- `prism-bridge/vendor/`: DLL do Prism e licenças de terceiros;
- `tools/`: utilitários de análise estática usados na pesquisa;
- `docs/`: documentação em português e inglês.

Arquivos criados em execução:

- `SiderAddons/pes_a11y_speech.txt`: última mensagem entregue ao bridge;
- `SiderAddons/sider.log`: log do Sider e do módulo;

O antigo gatilho de captura extensa de widgets foi desativado na versão 0.1.4 para evitar bloqueios da thread de renderização.

## Endereços identificados

Os RVAs abaixo pertencem somente ao executável estudado:

| Rotina | RVA | Uso |
|---|---:|---|
| Saída do resolvedor de localização | `0x1496A3C` | Texto UTF-8, comprimento e ID |
| Inicialização de slider | `0xE59F80` | Objeto, mínimo, máximo e valor |
| Mudança de slider | `0xE5A190` | Novo valor |
| Definição final de texto da UI | `0xE48BF0` | Texto dinâmico associado ao widget |
| Item central da lista de ligas | `0xC97408` | Registro da liga realmente selecionada |
| Nome alternativo do clube central | `0xC97C32` | Nome modificado do clube selecionado |
| Nome padrão do clube central | `0xC97CA8` | Nome do banco de dados do clube selecionado |
| Idioma do texto do jogo | `0xB22A50` | Índice de idioma |
| Idioma dos comentários | `0xB229F0` | Índice de idioma |
| Navegação do idioma de texto | `0xB22871` | Movimento no seletor |

O resolvedor retorna o ponteiro da string em `RAX`, o tamanho em `R8` e o ID de localização em `EDI`. Campos de foco genéricos dos widgets são reciclados e não identificam com segurança o item visível. Para ligas e clubes, a versão 0.1.4 intercepta os renderizadores nativos de nove células e anuncia o registro central, de índice `4`, que o próprio jogo trata como selecionado. Os demais controles continuam combinando estabilização, gerações de navegação, textos recentes e sinais específicos.

## Compilação do bridge

No diretório `prism-bridge`:

```powershell
dotnet publish -c Release -r win-x64 --self-contained false
```

Teste manual do backend:

```powershell
pes-a11y-prism-bridge.exe --test
```

## Roteiro mínimo de teste

1. Confirme que o menu principal e o tooltip são falados.
2. Entre e volte dos submenus de Football Life, Liga Master e Configurações.
3. Navegue lentamente e depois rapidamente, verificando atraso, silêncio, repetição e item fora de ordem.
4. Teste os sliders de som e confirme que mudanças laterais anunciam somente o novo valor.
5. Teste seleção de lado, ligas, clubes, time visitante, pré-partida, idiomas, câmera e velocidade.
6. Em caso de falha, feche o jogo e preserve `SiderAddons/sider.log` antes de uma nova execução.

## Recuperação

Os hooks vivem apenas na memória e desaparecem ao fechar o jogo. Para desativar o mod na próxima execução, comente a linha em `sider.ini`:

```ini
; lua.module = "pes_a11y_menu_string_probe.lua"
```

O mod não altera `FL_2026.exe`.

## Distribuição e licenças

O pacote não inclui o jogo, o Sider nem arquivos proprietários do Football Life/PES. O Prism e seus componentes mantêm os avisos e licenças presentes em `prism-bridge/vendor`. O repositório ainda não declara uma licença própria para o código do mod; escolha uma antes de aceitar contribuições ou redistribuições externas.
