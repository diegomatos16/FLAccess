# FLAccess 0.1.7

Publicado em 21 de outubro de 2026. Leitura experimental de menus do SP Football
Life 2026 / PES 2021, sem OCR, usando dados internos do jogo e o Prism.
Não oferece acessibilidade completa às partidas.

## Instalação

Requer Windows x64, Football Life 2026 com o executável compatível `FL_2026.exe`
e Sider 7.3.3 funcional. Use NVDA ou outro leitor compatível; sem leitor ativo,
o Prism pode usar SAPI.

1. Feche o jogo e o Sider e faça backup dos arquivos que vai substituir.
2. Extraia o pacote `FLAccess-0.1.7-sider.zip`.
3. Copie a pasta `modules` do pacote para `SiderAddons/modules`, mesclando as pastas.
4. No bloco `[sider]` do `sider.ini`, acrescente uma única linha:

```ini
lua.module = "FLAccess.lua"
```

5. Inicie pelo Sider. Não substitua o `sider.ini` inteiro.

O pacote inclui o módulo Lua, o Prism com suas licenças e índices de texto PT/EN.
Não é necessário Python nem um programa auxiliar para usar o mod.
Não inclui `sider.dll`. A leitura dos painéis textuais dos outros módulos do
Sider exige o núcleo modificado que fornece `overlay_content`; o código dessa
alteração está em `sider-core`. Sua redistribuição compilada depende de
autorização do mantenedor. A leitura dos menus do jogo usa os próprios hooks.
Quem já usa o núcleo compatível pode mantê-lo.
