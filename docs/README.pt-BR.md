# FLAccess 0.1.8

Publicado em 26 de outubro de 2026. Leitura experimental de menus do SP Football
Life 2026 / PES 2021, sem OCR, usando dados internos do jogo e o Prism.
Não oferece acessibilidade completa às partidas.

## Instalação

Requer Windows x64, Football Life 2026 com o executável compatível `FL_2026.exe`
e Sider 7.3.3 funcional. Use NVDA ou outro leitor compatível; sem leitor ativo,
o Prism pode usar SAPI.

1. Feche o jogo e o Sider e faça backup dos arquivos que vai substituir.
2. Extraia o pacote `FLAccess-0.1.8-sider.zip`.
3. Copie a pasta `modules` do pacote para `SiderAddons/modules`, mesclando as pastas.
4. Copie o `sider.dll` do pacote para `SiderAddons`, substituindo somente o núcleo
   compatível 7.3.3. Não use esse DLL em outra versão do Sider.
5. No bloco `[sider]` do `sider.ini`, acrescente uma única linha:

```ini
lua.module = "FLAccess.lua"
```

6. Inicie pelo Sider. Não substitua o `sider.ini` inteiro.

O pacote inclui o módulo Lua, o Prism com suas licenças e índices de texto PT/EN.
Não é necessário Python nem um programa auxiliar para usar o mod.
Inclui o `sider.dll` modificado 7.3.3 já usado nos testes locais, com o evento
`overlay_content` para ler os painéis textuais dos outros módulos do Sider e a
correção de alinhamento de pilha. O código correspondente está em `sider-core`.
A leitura dos menus do jogo usa os próprios hooks.

## Uso

Navegue no jogo com seus comandos habituais. Para revisar os textos disponíveis,
use I/K/J/L em uma sequência única, sem categorias. O analógico direito só é
aproveitado onde não conflita com o jogo. A revisão contém apenas o que o mod
conseguiu associar ao contexto atual.

No painel do mod no Sider: 6 e 7 escolhem a opção, 9 e 0 alteram o valor,
8 restaura o padrão. O diagnóstico inicia desligado. A digitação não recebe eco
de inserção pelo mod; exclusão e movimento do cursor têm feedback quando detectados.
O próprio leitor de telas pode ter uma configuração independente de eco.

## Mudanças e limites

A 0.1.8 reúne a base da dev 25: associação comum entre foco, nome, valor e
contexto; validação antes de falar; descarte de texto antigo; revisão de textos;
tratamento de diálogos, edição e estruturas nativas de listas e comandos.
As regras novas seguem componentes e vínculos internos, sem tabelas de telas.

No jogador em foco, K (analógico direito para baixo) começa no número/nome,
depois posição principal, secundárias completas/parciais e posição no campo.
I (analógico para cima) volta. Fora do campo: Não está no campo. A situação
titular/reserva/não relacionado fica somente na navegação entre jogadores.
Opções do plano de jogo e nomes em Editar posição foram confirmados pelo usuário.

O usuário confirmou anteriormente câmera, estádio, valores da Master Liga,
segunda confirmação da Master Liga, conteúdo do nome do treinador e configurações
da Champions. Isso não comprova ausência de regressões na base final.

Continuam pendentes de validação ou investigação: título inicial completo,
guia ativa do treinamento, países, seleção inicial de ligas/clubes, revisão do
elenco ao escolher clube, confirmação do treinador após editar, botão de Pular,
introdução e tela principal da Master Liga, situação titular/reserva/não relacionado
e anúncio Em casa/Neutro/Fora. Não se promete leitura de qualquer tela.

Os testes internos da dev 25 passaram, incluindo 321 verificações Lua por cópia,
38 testes Python, sandbox e 15 assinaturas do executável. São verificações internas;
não substituem audição no jogo. A publicação preserva a lógica dev 25, com identificação pública 0.1.8. Consulte [notas da versão](RELEASE-0.1.8.pt-BR.md) e
[matriz de pendências](TESTES-LEITURA-PENDENCIAS.pt-BR.md).
