# Instalação do FLAccess 0.1.5

1. Feche o jogo e o Sider.
2. Faça backup da pasta `SiderAddons` da instalação.
3. Copie `sider.dll` para `SiderAddons`, substituindo somente o DLL 7.3.3 existente.
4. Copie a pasta `modules` deste pacote para `SiderAddons`, mesclando-a com a
   pasta `SiderAddons/modules` existente.
5. Adicione a linha de `sider.ini.snippet` ao bloco `[sider]` do seu `sider.ini`.
6. Abra o jogo normalmente com o Sider.

Não substitua o seu `sider.ini` inteiro. O módulo Lua, `prism.dll` e suas
licenças ficam dentro de `SiderAddons/modules`. O Prism é carregado diretamente
pelo módulo; não há EXE, CMD, terminal nem requisito do .NET.
O `sider.dll` incluído é o núcleo oficial 7.3.3 com um evento de acessibilidade
adicionado para ler o texto dos painéis de todos os módulos e a correção oficial
de alinhamento de pilha do 7.3.4. Não use esse DLL em outra versão do Sider.

No painel de acessibilidade do Sider, use `6` e `7` para navegar pelas opções,
`9` e `0` para alterar e `8` para restaurar o padrão. `Ler tooltips` é salvo em
`SiderAddons/modules/FLAccess.ini`; o diagnóstico começa sempre desligado.

Compatibilidade: versão experimental criada para o `FL_2026.exe` estudado. Consulte `docs/README.pt-BR.md` para limitações e recuperação.

Limitação conhecida da 0.1.5: o Plano de jogo, seus submenus e a seleção de
jogadores em Editar posição permanecem instáveis e serão investigados na 0.1.6.
