# FLAccess

Versão publicada: **0.1.5**  
Data: **11 de setembro de 2026**

## Objetivo

Este projeto pesquisa acessibilidade de menus sem OCR para o SP Football Life 2026, baseado no PES 2021. Ele captura textos e sinais de foco diretamente das estruturas internas do jogo, usando um módulo Lua do Sider, e os envia ao leitor de telas pela API C nativa do Prism. Se nenhum leitor compatível estiver ativo, usa o Microsoft SAPI.

A versão 0.1.5 é experimental. Ela torna partes dos menus falantes, incluindo a seleção correta de ligas e clubes, mas ainda não oferece acessibilidade completa às partidas. O Plano de jogo não é considerado acessível nesta versão e continuará sendo investigado na 0.1.6.

## Instalação do pacote pronto

Pré-requisitos:

- SP Football Life 2026 com o executável compatível `FL_2026.exe`;
- Sider funcional;
- Windows x64;
- leitor de telas compatível opcional; sem leitor ativo, o mod usa SAPI.

Procedimento:

1. Feche o jogo e o Sider.
2. Faça backup da pasta `SiderAddons`.
3. Copie o `sider.dll` do pacote para `SiderAddons`, substituindo o DLL 7.3.3.
4. Copie a pasta `modules` do pacote para `SiderAddons`, mesclando-a com
   `SiderAddons/modules`.
5. Acrescente ao bloco `[sider]` de `SiderAddons/sider.ini`:

```ini
lua.module = "FLAccess.lua"
```

6. Inicie o jogo pelo fluxo normal do Sider. O Prism escolherá automaticamente
   um leitor compatível ou SAPI.

O módulo carrega `prism.dll` diretamente dentro do jogo depois que a renderização
começa. Não há programa auxiliar, terminal, CMD ou requisito do .NET.

## O que foi confirmado

- carregamento automático pelo Sider;
- inicialização automática do Prism junto com o jogo;
- seleção automática entre os leitores registrados pelo Prism;
- troca para outro leitor ou SAPI quando o leitor ativo é fechado;
- detecção de um leitor iniciado enquanto SAPI está ativo;
- leitura do texto de todos os módulos que produzem um painel textual do Sider;
- leitura completa na primeira abertura de um painel e, nas mudanças seguintes,
  anúncio apenas da opção selecionada ou do conteúdo novo;
- painel do mod em português quando o texto do jogo está em português do Brasil
  ou de Portugal; inglês nos demais idiomas;
- captura interna de strings UTF-8, sem OCR;
- leitura do menu principal e de seus tooltips no fluxo testado;
- leitura de rótulos, valores e mudanças laterais em sliders de áudio;
- leitura de várias listas e telas de configurações que usam widgets conhecidos;
- leitura parcial de opções e valores nos ajustes do controle e nas configurações gerais;
- anúncio apenas do novo valor em mudanças laterais reconhecidas;
- leitura de tooltips após uma pequena pausa em telas compatíveis;
- opção persistente `Ler tooltips: Sim/Não`; `6` e `7` navegam, `9` e `0`
  alteram a opção, e `8` restaura o padrão;
- modo de diagnóstico seguro no mesmo painel. Ele registra apenas mudanças
  estáveis de foco e de sliders, sem despejo contínuo de memória;
- leitura de algumas caixas de diálogo `Sim`/`Não`;
- leitura nativa e sincronizada da liga realmente selecionada;
- leitura nativa do clube realmente selecionado, incluindo nomes padrão e nomes alternativos/modificados;
- seleção de ligas e clubes confirmada na Premier League e no Brasileirão;
- redução de anúncios repetidos ou pertencentes à tela anterior.

## Cobertura experimental e limitações

Os testes mais recentes mostraram que a leitura ainda pode deixar de acompanhar o foco ao entrar ou voltar de uma tela. Em especial:

- o primeiro submenu depois do menu principal pode ficar silencioso;
- a tela `Bem-vindo ao Football Life`, com modos como amistoso, liga, copa e cooperativo, não é confiável em todas as entradas;
- a seleção horizontal `Em casa`, `Neutro` e `Fora` funcionou no fluxo testado, mas combinações com vários controles ainda precisam de cobertura mais ampla;
- a leitura nativa de ligas e clubes foi validada no fluxo de amistoso testado; outros modos ainda precisam de testes completos;
- a seleção do time visitante ainda precisa ser retestada com o novo leitor nativo de clubes;
- a lista de ações da pré-partida agora trata o foco múltiplo observado na
  primeira entrada, mas ainda precisa de validação em mais modos;
- o Plano de jogo permanece quebrado e imprevisível: jogadores e formações
  animados compartilham sinais de foco com o menu, podendo silenciar ou atrasar
  as opções da tela principal e dos submenus;
- em `Escalação/Editar posição`, o jogador selecionado, a separação entre
  titulares e reservas e a leitura de atributos ainda não são confiáveis;
- a cobertura do Plano de jogo deve ser tratada apenas como pesquisa interna na
  0.1.5; a investigação estrutural continuará na 0.1.6;
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
  -> API C nativa de prism.dll
  -> NVDA, outro leitor compatível ou SAPI
```

O módulo espera a renderização começar antes de carregar o Prism. A fala é
entregue diretamente à DLL: navegação rápida interrompe a fala anterior e
mensagens explicitamente enfileiradas, como o botão posterior a um diálogo,
usam o modo de fila do próprio Prism.

## Estrutura do código

- `modules/FLAccess.lua`: módulo principal do Sider;
- `modules/FLAccess_gameplay.lua`: componente isolado reservado para futuros
  recursos sonoros durante partidas; permanece inativo na versão 0.1.5;
- `modules/FLAccess-Prism/`: `prism.dll` e licenças;
- `sider-core/sider.cpp`: fonte do núcleo Sider 7.3.3 com o evento `overlay_content`;
- `sider-core/util.asm`: correção oficial de alinhamento da pilha do Sider 7.3.4,
  aplicada ao núcleo 7.3.3;
- `tools/`: utilitários de análise estática usados na pesquisa;
- `docs/`: documentação em português e inglês.
- `docs/ARCHITECTURE.pt-BR.md`: limites entre leitor de telas, Prism e
  jogabilidade.

Arquivos criados em execução:

- `SiderAddons/sider.log`: log do Sider e do módulo;
- `SiderAddons/modules/FLAccess.ini`: preferência persistente de tooltips.
- `SiderAddons/FLAccess-diagnostic.log`: captura estrutural criada somente
  quando o modo de diagnóstico é ativado.

O antigo gatilho de captura extensa de widgets continua desativado para evitar
bloqueios da thread de renderização. O diagnóstico novo registra ponteiro e
vtable do widget selecionado, RVA do chamador que definiu o texto, campos de
foco, rótulo, valor, tipo de controle, relações com widgets conhecidos e um
inventário limitado dos textos recentes da tela. O arquivo é aberto somente
quando ocorre um evento estável.

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

## Roteiro mínimo de teste

1. Confirme que o menu principal e o tooltip são falados. Abra o painel do mod,
   desligue `Ler tooltips` e confirme que os tooltips deixam de ser anunciados.
2. Entre e volte dos submenus de Football Life, Liga Master e Configurações.
3. Navegue lentamente e depois rapidamente, verificando atraso, silêncio, repetição e item fora de ordem.
4. Teste os sliders de som e confirme que mudanças laterais anunciam somente o novo valor.
5. Teste seleção de lado, ligas, clubes, time visitante, pré-partida, idiomas, câmera e velocidade.
   Na pré-partida, confirme especialmente que navegar não fecha mais o jogo.
6. No estádio, confirme anúncios no formato `nome, seletor, valor`. Testes no
   Plano de jogo são apenas exploratórios na 0.1.5: registre separadamente
   silêncio, itens incorretos e jogadores anunciados fora de contexto para a
   investigação da 0.1.6. O FLAccess não intercepta `R3`.
7. Volte da pré-partida e teste `Sim` e `Não` no aviso de perda das configurações.
8. Em caso de falha, feche o jogo e preserve `SiderAddons/sider.log` antes de uma nova execução.

## Diagnóstico estrutural de uma tela

1. Abra o painel do mod com `Espaço`.
2. Use `6` ou `7` até ouvir `Modo de diagnóstico`.
3. Use `9` ou `0` para ativar. O arquivo anterior é substituído nesse momento.
4. Feche o Sider e reproduza apenas a tela problemática, passando uma vez por
   cada opção relevante.
5. Abra o painel novamente, selecione `Modo de diagnóstico` e use `9` ou `0`
   para desativar.
6. Envie `SiderAddons/FLAccess-diagnostic.log` junto com uma descrição das teclas
   usadas e do que deveria ter sido falado.

O modo começa sempre desligado após reiniciar o jogo. `8` restaura seu padrão,
que é `Não`.

Enquanto o painel do Sider estiver visível, a leitura do jogo e a coleta
estrutural ficam pausadas para não misturar duas interfaces. Isso é esperado:
feche o painel com `Espaço` depois de ativar o diagnóstico.

## Recuperação

Os hooks vivem apenas na memória e desaparecem ao fechar o jogo. Para desativar o mod na próxima execução, comente a linha em `sider.ini`:

```ini
; lua.module = "FLAccess.lua"
```

O mod não altera `FL_2026.exe`.

## Distribuição e licenças

O pacote de teste 0.1.5 inclui um `sider.dll` 7.3.3 modificado, compilado a partir
do código oficial no commit `112627c`. O repositório oficial não apresenta uma
licença de redistribuição; portanto, esta compilação é apenas para teste local e
não deve ser publicada sem autorização do mantenedor do Sider. O pacote não
inclui o jogo nem arquivos proprietários do Football Life/PES. O Prism mantém
os avisos e licenças presentes em `modules/FLAccess-Prism/licenses`.
