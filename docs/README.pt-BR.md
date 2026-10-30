# FLAccess 0.1.9

Leitor experimental de menus para SP Football Life2026/PES2021, sem OCR, usando
texto e foco nativos. Inclui Gameplay experimental opcional. Requer Windows x64,
FL_2026.exe compatível e Sider 7.3.3. Compatibilidade FL 27 não estabelecida.

## Instalação

Baixe [FlAccess.zip e SHA256SUMS.txt](https://github.com/diegomatos16/FLAccess/releases/tag/v0.1.9).
Siga o [guia de instalação e migração](../packaging/INSTALL.pt-BR.md). O ZIP tem
livecpk/modules/sider; copie sider/sider.dll para a raiz do SiderAddons. Não
substitua o sider.ini inteiro. Use as entradas do snippet e remova entradas antigas
do FLAccess. Faça backup das preferências, sons e perfis personalizados.

Reader e Gameplay podem ser ativados separadamente. Não requer Python para jogar.
NVDA ou outro leitor compatível fala pelo Prism; SAPI pode ser usado como fallback.

## Controles

Navegue normalmente pelos controles do jogo. I/análogo DIREITO para cima revisa
o dado anterior; K/direito para baixo, o próximo. J vai ao primeiro; L repete.
Um dado completo por passo. Perguntas/mensagens mostram somente seu conteúdo no
buffer; respostas continuam pela navegação original. Listas e tabelas reconhecidas
restringem revisão ao registro selecionado. Y/Triângulo abre dados do jogador e
anuncia título; Ajuda/Voltar ficam fora da revisão dos atributos.

No painel do Reader no Sider,6/7 escolhem a opção,9/0 mudam valor e8 restaura padrão.
Diagnóstico inicia desligado. Eco de inserção pelo mod permanece desligado;
exclusão e movimento do cursor podem ter feedback. Eco do próprio leitor é separado.

Gameplay não cria novos comandos. Segue partida/jogador local e usa efeitos
HRTF/OpenAL. Para desativá-lo, remova sua linha lua.module. Para configurações de
câmera, desarme e WAVs, veja [README Gameplay](../modules/FlAccessGameplay/README.pt-BR.md).

## Mudanças e limites

Escalação, substituição, atributos agrupados, treino, áudio/idioma, pausa e revisão
receberam melhorias. Posições originais/secundárias erradas foram retiradas;
posição no campo permanece. Estilos e posições reais ficam para futuro.

Persistem relatos de lentidão/silêncios, primeiro item, países, mensagens parciais,
tabelas e tooltips. Correções internas recentes ainda precisam de confirmação real.
Orientação das câmeras e demais efeitos de gameplay são experimentais; não se
promete controle completo da partida, autowalk ou leitura de qualquer tela.
Veja [notas completas](RELEASE-0.1.9.pt-BR.md) e [pendências](LISTA-PROBLEMAS-ATUAL.pt-BR.md).
