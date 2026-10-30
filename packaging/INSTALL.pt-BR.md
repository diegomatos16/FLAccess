# Instalação — FlAccess.zip — 0.1.9

O ZIP contém três pastas: `livecpk`, `modules` e `sider`.
Há dois mods independentes: **FlAccessReader** (menus) e **FlAccessGameplay**
(radar e informações da partida). Novas leituras de tempo/placar ainda não foram
implementadas. Gameplay é experimental e pode ser desativado separadamente.

1. Feche o jogo e o Sider. Faça backup do seu sider.ini e sider.dll.
2. Extraia FlAccess.zip. Copie `livecpk` e `modules` para dentro do SiderAddons,
   mesclando as pastas e preservando os demais mods.
3. A pasta `sider` do ZIP contém o núcleo compatível. Copie `sider/sider.dll` para
   `SiderAddons/sider.dll`. A DLL precisa ficar nessa raiz, não em SiderAddons/sider.
   Esta DLL é para o Sider 7.3.3 compatível documentado; não instalar sobre outra
   versão sem verificar compatibilidade.
4. Dentro do bloco [sider] existente, acrescente as entradas de
   `sider/sider.ini.snippet`. Não substitua o sider.ini inteiro. São duas entradas
   lua.module: FlAccessReader.lua e FlAccessGameplay.lua. Cada uma pode ser ativada
   ou desativada separadamente.
5. Na migração, remova apenas as entradas antigas FLAccess.lua, FLAccess_audio.lua,
   FLAccess_match_registry.lua e FLAccess_gameplay_live.lua. Não carregar versões
   antigas junto das novas. Preserve os demais módulos instalados.
6. Para manter preferências antigas, copie modules/FLAccess.ini para
   modules/FlAccessReader/FlAccessReader.ini antes do primeiro uso.
7. Inicie o jogo normalmente pelo Sider.

## Sons e assets

Sons WAV abertos ficam em `livecpk/FlAccessGameplay/sounds`. Você pode trocar os
arquivos diretamente ali; mantendo o nome, reabrir o jogo garante recarga. Um nome
novo precisa ser ligado a um evento pelo motor. Os textos do Reader ficam em
`livecpk/FlAccessReader/text`. DLLs/código ficam em modules; logs não são assets.
Os módulos leem esses WAVs/TSVs diretamente: LiveCPK não toca WAVs automaticamente.

## Compatibilidade e estado

A base foi investigada no FL 2026/FL_2026.exe com Sider 7.3.3. A estrutura pode ser
reutilizada no futuro, mas FL 27 precisa de verificação de executável, Sider e
assinaturas. Não instalar DLL de núcleo incompatível supondo que o nome do ZIP
assegura suporte. Reader0.1.9 (base 42); Gameplay experimental 16. Bola aprovada
antes da reorganização; laterais, orientação e posse ainda aguardam audição real.

Prism e OpenAL acompanham suas licenças nas pastas dos respectivos módulos.

Antes de atualizar, faça backup dos WAVs e INIs personalizados: o pacote traz padrões.
Não adicione entradas separadas para arquivos internos de engine/.
