# FLAccess 0.2.0 — experimental

Compatibilidade experimental com Football Life 27, aprimoramento da navegação e
exploração, alguns bugs corrigidos, mas mais pendências. Reader 52 / Gameplay 19.
Leitor e gameplay no mesmo mod, dividido em 31 componentes Sider. Leitor base
sempre ativo. Usa texto/foco nativos e Prism, sem OCR, no Windows x64.

## Instalação

Baixe [FlAccess.zip e SHA256SUMS.txt](https://github.com/diegomatos16/FLAccess/releases/tag/v0.2.0)
e siga a [instalação/migração](../packaging/INSTALL.pt-BR.md). O ZIP contém
content/modules/sider, incluindo o Sider 7.3.3 compatível e DLLs/licenças.
Não substitua o sider.ini inteiro. Preserve outros mods, INIs, WAVs e perfis.
Recursos próprios não usam cpk.root. Não carregar FlAccessReader/FlAccessGameplay
antigos junto com 0.2.0. Python não é necessário para jogar.

## Controles

Navegue pelos controles normais do jogo. I/analógico DIREITO para cima explora
o campo anterior; K/direito para baixo, o próximo. J vai ao primeiro campo;
L está sem ação. Repetir foi removido. J/L e direito horizontal para notícias
ainda não implementados. Um campo completo por passo, com título do grupo ao
entrar nele quando o componente é reconhecido.

Atributos ficam só na exploração; seleção automática mantém nome/situação e os
registros reconhecidos da classificação. Perguntas/mensagens limitam exploração
ao conteúdo; respostas usam os controles originais. Y/Triângulo abre dados do
jogador nos fluxos suportados.

No painel FLAccess do Sider,6/7 escolhem a opção,9/0 mudam valor e 8 restaura padrão.
Diagnóstico começa desligado. Eco de inserção do mod começa desligado; exclusão
e movimento do cursor podem ter feedback. Eco do leitor é separado.
Configuração unificada: modules/FlAccess/FlAccess.ini. Sons e perfis editáveis em
content/FlAccess/sounds e content/FlAccess/cameras. Gameplay usa HRTF/OpenAL e
continua experimental; controles individuais de sons são trabalho futuro.

## Pendências

Listas de clubes/ligas/jogadores e classificação continuam com relato de lentidão
grave.52 não tem confirmação real. Também permanecem menu principal duplicado/
tooltip ausente, submenu Football Life e painéis silenciosos, dados de jogador
sem agrupamento consistente, Diário/notícias/data e rolagem da Master Liga,
save/sobrescrita e relatos de áudio após substituição/desarme.

Novo relato no FL27: opções dos outros módulos Sider não são mais lidas.
Não declarar corrigidos esses fluxos apenas porque testes automatizados passam.
Consulte [notas 0.2.0](RELEASE-0.2.0.pt-BR.md) e a
[lista detalhada](LISTA-PROBLEMAS-ATUAL.pt-BR.md).
