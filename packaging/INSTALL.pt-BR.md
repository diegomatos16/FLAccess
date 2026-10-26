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
