# FLAccess 0.1.9 — 30/10/2026

Mais melhorias no sistema de leitura de tela, incluindo melhorias na escalação,
atributos e outros. Esta publicação reúne o Reader baseado na dev42 e, por decisão
do responsável, inclui também o Gameplay experimental 16. As duas partes funcionam
separadamente. As versões anteriores permanecem disponíveis.

## Instalação e migração

Baixe **FlAccess.zip** e **SHA256SUMS.txt** na Release v0.1.9. O ZIP contém somente
`livecpk`, `modules` e `sider`. Siga [instalação](../packaging/INSTALL.pt-BR.md).
Copie `sider/sider.dll` para a raiz do SiderAddons compatível7.3.3. Mescle os outros
arquivos e use o snippet no bloco [sider] existente. Preserve os demais mods.
Remova as entradas antigas FLAccess.lua/FLAccess_audio/FLAccess_match_registry/
FLAccess_gameplay_live; não carregar antigas e novas simultaneamente. Migre
FLAccess.ini para modules/FlAccessReader/FlAccessReader.ini, se quiser preservá-lo.
Faça backup dos WAVs e INIs personalizados antes de atualizar: o ZIP inclui padrões.

O pacote e o repositório incluem Sider modificado, Prism, OpenAL Soft e master de
áudio com fontes/licenças correspondentes. Python não é necessário para jogar.
Base investigada: Windows x64, FL 2026/FL_2026.exe e Sider 7.3.3. FL 27 não foi validado.

## Leitor de tela: mudanças desde a 0.1.8

- Escalação: vínculo de jogador por ID, slot e lado; nomes acompanham o alvo da
  substituição, sem repetir o jogador de origem nem silenciar os outros. Situação
  titular/reserva/não relacionado é anunciada ao entrar/trocar de grupo. Jogador
  parado não deve ser repetido por redesenho da legenda. Ajuda passa a associar
  nomes e valores das opções; leitura de memória inválida recebe cópia segura.
- Informações do jogador: Y/Triângulo anuncia o título; revisão traz apenas dados,
  sem Ajuda, Voltar e outros comandos. Um dado completo por passo, com rótulo e
  unidade: altura, peso e atributos. Posição no campo é identificada separadamente.
  Posição principal e secundárias completas/parciais incorretas foram retiradas.
  Estilos de jogo e posições reais permanecem trabalho futuro; não inferir posição
  original pela formação nem pelo estilo.
- Treino: guias Iniciante/Intermediário/Avançado são lidas antes do exercício.
  Troca de formação anuncia somente4-4-2/4-3-3 etc, sem prefixo repetido.
- Áudio: nomes/valores de volume e título Idioma do comentário corrigidos.
  Metadados musicais passivos ficam silenciosos; trilha sonora permite ouvir
  faixa/artista/estado quando os dados nativos estiverem disponíveis.
- Pausa: título próprio Menu de pausa e leitura das opções, sem confundir aviso
  pré-partida. Troca de usuário com LT/RT anuncia nome e Em casa/Neutro/Fora.
- Navegação/revisão: I/K e analógico DIREITO cima/baixo usam o mesmo buffer;
  J vai ao primeiro dado e L repete. Perguntas/diálogos deixam apenas mensagem
  no buffer; respostas continuam pelos controles do jogo. Notícias, mensagens e
  listas reconhecidas restringem revisão ao conteúdo/jogador selecionado.
- Carregamento nativo contínuo: aviso único Carregando tela após 3 segundos.
  Transições rápidas ficam silenciosas; bloqueio completo de render limita o aviso.
- Padrões de tabelas: agrupamento de campos rotulados por linha/dia selecionado,
  incluindo classificação/calendário reconhecidos. Revisão permanece nesse registro,
  sem percorrer todas as colunas soltas ou misturar outras linhas.
- Menu principal: Football Life usa o mesmo par nativo nome/descrição e publicador
  das demais opções. Retirado o publicador inicial separado e seus caches de nomes.
  O cartão informativo do projeto permanece passivo; controles originais preservados.
- Países: segue ID selecionado no vetor filtrado e nome exato na base atual do jogo;
  não confunde o renderizador de países com a lista genérica de continentes.

## Desempenho, estabilidade e manutenção

Publicação de voz concentrada depois da atualização do foco, até duas tentativas
por quadro. Entradas antigas são revalidadas/canceladas. Estados de país, tooltip,
mensagem e fragmentos compartilham entrega/cancelamento; falha de trecho não confirma
a mensagem inteira. Erro de conversão13 não alterna repetidamente NVDA e SAPI.
Falhas reais de conexão ainda têm recuperação limitada. Voz continua síncrona em
Lua: chamada lenta pode atrasar um quadro; não há garantia de fim das travadas.

Leituras repetidas, strings e consultas compartilham cache somente na fase síncrona;
cache é descartado antes da comunicação com Prism e ao sair. RPM seguro verifica
regiões/páginas e rejeita ponteiros indisponíveis. Corrigido erro cdata/math.floor
que abortou1686 callbacks no log da41, inclusive principal e tabelas. Testes anteriores
normalizavam ponteiros antes da chamada e não cobriam esse caso real.

Fonte Reader dividido em16partes de engine/, geradas em UM Lua compatível com Sider;
Gameplay também tem componentes gerados. Removidos helpers sem uso e publicação/
consultas duplicadas. Builders verificam artefatos e DLLs obrigatórias. Fontes e
instruções do master de áudio estão em audio-core. Sem bibliotecas novas nesta
última refatoração de leitura.

## Gameplay experimental incluído

- Dois módulos independentes: Reader pode ser usado sem Gameplay e vice-versa.
  Não altera os comandos originais nem oferece caminhada automática.
- Radar sonoro HRTF/OpenAL: bola com ganho por distância, laterais próximas e
  centros fixos dos gols. Posse confirmada pode centralizar a bola; avisos de ganho,
  perda e continuidade após passe usam eventos distintos.
- Alerta experimental de proximidade de desarme, configurável no INI. Não garante
  alcance nativo nem sucesso do desarme. É possível desativá-lo pelo INI.
- Projeção usa matriz de visão/projeção e jogador controlado, com dez perfis de
  câmera separados. Editar os INIs instalados aplica ajustes ao reabrir o jogo;
  perfil ausente usa padrão, inválido silencia só seu radar direcional.
- Efeitos acompanham volume/mudo da sessão do jogo no Windows, com vínculo dentro
  do processo; não instala reprodutor externo. WAVs ficam abertos/editáveis em
  livecpk/FlAccessGameplay/sounds. Assets ausentes silenciam o efeito correspondente.
- Suporte atual é experimental para um jogador local. Detalhes e limites em
  [README Gameplay](../modules/FlAccessGameplay/README.pt-BR.md).

## Confirmações e pendências

O usuário confirmou nesta série correções de treino, volumes/idioma, título e
opções da pausa, atributos agrupados, navegação direita/I/K, substituição, Ajuda,
trilha sonora e troca de usuário. Aprovações não significam cobertura universal.

Continuam abertos: lentidão/silêncios na navegação rápida, primeiro Football Life,
países, conteúdo parcial de mensagens, classificação/calendário e tooltips de
instruções ofensivas. Os últimos ajustes da42 passaram nos testes internos, mas
não receberam nova confirmação no jogo antes desta publicação. Buffer em painéis
sem vínculo nativo, outros fluxos da Master Liga e outras pendências seguem na
[lista atual](LISTA-PROBLEMAS-ATUAL.pt-BR.md). Não se promete leitura de toda tela.

Gameplay: bola teve aprovação histórica; orientação por câmera, laterais, gols,
posse e desarme ainda precisam de validação audível. Há relato de orientação ruim
em Dinâmica ampla/Estádio. Perfis não foram todos calibrados por audição. Tempo/
placar falados, posições reais e estilos de jogo são trabalho futuro.

## Validação

Base Reader:410 verificações Lua por cópia,60 Python, sandbox16 eventos/16 assinaturas.
Novos testes usam RPM real no processo de teste, ponteiros cdata, dez países/cinco
grupos e quatro linhas de classificação/calendário. Não são audição do jogo.
Base Gameplay16:191 contratos de câmera,104 de gameplay e verificações do ciclo de
áudio/pacote. A publicação confere novamente os módulos e a extração do instalador.
O manifesto sider/BUILD.json liga cada arquivo ao hash e commit de origem.
Testes não encerram relatos reais nem comprovam FPS ou ausência de crashes.
