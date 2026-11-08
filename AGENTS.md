## Leitura de menus e diálogos

- Antes de implementar ou corrigir uma leitura, procure outros menus, modos e torneios que usam o mesmo componente, evento ou estrutura. Confira o código, as capturas e os logs disponíveis.
- Aplique a regra no componente compartilhado com evidência de foco e visibilidade. Use exceções por tela somente quando o jogo fornecer estruturas diferentes, e registre quais variantes foram verificadas.
- Anuncie “OK” quando for uma ação que o jogador pode selecionar ou acionar. Uma legenda de controle, texto decorativo ou texto de fundo pode aparecer no painel sem representar um botão.

## Publicação0.2.0 autorizada — 04/11/2026

Publicação preparada Reader52/Gameplay19,31módulos, tagv0.2.0. Notas PT/EN e
pendências incluídas também no ZIP (sider/RELEASE.*). 65Pythonpassam+1skip.
Commit: feat: compatibilidade experimental com Football Life 27.
Manter sem correção nova nesta rodada. Autorizado enviar main/tag e release
com FlAccess.zip/SHA256SUMS; release experimental como as anteriores.

Usuário agora autorizou explicitamente commit/envioGitHub/release0.2.0.
Mensagem solicitada: compatibilidade experimental Football27, aprimoramento
navegação, algunsbugs corrigidos, maispendências.51lento confirmado;52semteste.
Consolidar atuais em docs/RELEASE-0.2.0.pt-BR.md/en, README/instalação atuais;
pendência74agrupamentojogadores e75opçõesoutrosmódulosSiderFL27 semleitura.
Não inventar correções;66/71confirmados preservados. Aprovação atual prevalece
sobre proibições históricas de publicar/commit/push/tag abaixo. Nada de reabrir
investigação nesta publicação. Tagv0.2.0 ainda inexistente no remoto ao conferir.

## Reader52 / Gameplay19 — última tentativa, 04/11/2026

Usuário: última tentativa, senão subirbuildGitHub. Não presumir condição cumprida
nem publicar sem retorno; pergunta se51játestado enviada, sem resposta ainda.
Log51 preservado .test-temp/fl27-audit/sider51-return.log confirma build51,
busca30–32ms/janelas24–28ms/1200cópias. Agrupamento jogador AINDA números/rótulos
avulsos, não declararresolvido.52 remove window_graph_dirty porfocusdesconhecido;
troca dono/guia nãoapagatodosgrafos, layoutseleçãonãoresolvida aindainvalida.
Árvore expira6quadros da SUA coleta, não do último snapshot de cabeçalhos.
Window-refresh sumariza razões cada600quadros.449Lua/65Python+1skip/43contratos/
integração31/120framesPrism. Teste1200eventos30frames só5descobertasperiódicas;
donofechado/arestaremovida rejeitados. Sem FPS/audição52. Sem publicações.
Relatório docs/READER52-ULTIMA-TENTATIVA-LISTAS-2026-11-04.pt-BR.md.
Instalado52:31módulosiguais/30recursos+3DLLs+2estado+INIsintactos. ZIP52/97files.
Backupflaccess020-install-20261104-015929-356497.
Ao pedir teste normal encerrar turno, sem monitorar/pausas fixas/captura pesada.

## Reader51 / Gameplay19 — refatoração, 03/11/2026

Usuário confirmou título real junto do primeiro campo AO ENTRAR no grupo;
um campo/passo.50 continua lento, Salah lia rótulos sem valores. Log50 preservado
.test-temp/fl27-audit/sider50-return.log, janelas7–14ms, busca21ms/1258cópias.
51 reader_lists apóscontrols/antesobservations; reader_groups apóssemantics/
antesrecords. Total31 módulos. Listas reusam snapshot se headers+cursor frescos,
redescoberta até6quadros/mudança; ligações usadas sempre revalidadas, escalares
nunca atravessam IPC. Parameter caption só painel261e0c8, não1000nomes de lista.
Record_contains verifica escopo ANTESde ligações caras. Agrupamento comum usa
pares nativos/ancestralidade; mostrado7 semcursor liberado só exploração com
dono/grafo/valores atuais. Título nativo inequívoco porgrupo, sem categorias
inventadas; cabeçalhos velhos rejeitados. Atributos só exploração preservados.
447Lua/65Python+1skip/43contratosFL27/integração31,16eventos/23regs/120frames/
Prism. Instalado51,31módulosiguais/30recursos+3DLLs+INIintactos; sider.ini só
acrescenta2módulos. Backupflaccess020-install-20261103-125459-052014. ZIP51/97files.
Sem audição/FPS51.
Fonte nesteGit modules/FlAccess. Preservar66/71; ML/data/Diário/notícias/5times
não confirmados. J/L notícias pendente. Gameplay19/Prism/DLLs/sons preservados.
Relatório docs/READER51-LISTAS-GRUPOS-2026-11-03.pt-BR.md. Sem publicar/commit/
push/tag. Ao pedir navegação normal encerrar turno; sem pausas fixas/captura pesada.

## Reader50 / Gameplay19 — retorno49, 03/11/2026

49lento confirmado, classificação só5; usuário usa setas/direcional do JOGO.
Log preservado sider49-return.log: janelas9–15ms/quadro, fala quasezero/captura0.
50reusa grafo até6quadros com prova fresca de cada ligação usada (vetor/delegate/
árvore MSVC), janela/cursor/guardSWF; escalares nunca atravessam IPC. Fallback
para grafo incompleto/desconhecido. Teste100ramos707→91leituras, NÃO FPS real.
Classificação2684408/aed5d0/aedf80 usa índice e3d140 do GRUPO, não ficha0;
vetorWindow90/98 até48. Auto exige assinatura igual em outro quadro, exploração
um campo atual. Date carreira getter15765e0: Manager3705e10+48, Data1642a24
ano16/mês8/dia8; MainMenuML ativo tipado, contratos de código/dados; ao entrar+
primeiro campo exploração. Direito coletauma vez/passo, I inicial último.
441Lua/65Python+1skip/43contratosFL27/integração29. Sem audição/FPS/rolagem50.
Manualoficial acessível PES2019PC confirma direcional/A/B/Ajuda, NÃO comprova
rolagem exataFL27; links no relatório docs/READER50-LISTAS-CLASSIFICACAO-DATA-2026-11-03.pt-BR.md.
Preservar aprovações66/71. J/L notícias, Diário e liga/participantes pendentes;
67/70/data69 aguardam usuário. Gameplay19/DLLs/sons/INIs preservados. Sem escrita
de cursor ou envio de teclas; nada publicado/commit/push/tag. Ao pedir teste normal,
encerrar turno; sem pausas fixas/monitorar. Não rearmar captura completa.

## Reader49 / Gameplay19 — retorno48, 03/11/2026

Usuário CONFIRMOU Configurações sem sufixo e Sim/Não no diálogo (66/71).
Demais pendências ML/listas permanecem; jogo absurdamente pesado48 confirmado.
Capturas48 preservadas em .test-temp/fl27-audit/{components48-return,sider48-return}.log.
49native_field_label testa ancestralidade ANTES de validar textos históricos;
elimina passagem histórica redundante nos registros; metadados MSVC/dono usam
cache escalar da fase; menu_tree deriva subárvore de ancestral fresco somente
no MESMO callback, jamais de percurso truncado/cache anterior. Log separado por
janelas/textos/apresentação/captura. Teste comparativo48=1200sondagens alheias,
49=0;2nomes3cópias e PAGE_NOACCESS na próxima fase;436Lua/63Python+1skip/
41contratosFL27/integração29. Sem benchmark real49. Não rearmar captura pesada.
Descobertos news_title/news_text_0..2/journal_text_0..1/p_journal; schedule_date
são várias partidas, NÃO data atual comprovada. Notícias J/L, data ao entrar+
exploração, Diário, rolagem5times e liga/participantes seguem abertos. Sem escrita
de cursor/envio de teclas. Relatório docs/READER49-DESEMPENHO-2026-11-03.pt-BR.md.
Gameplay19/Prism/DLLs/sons/perfis/INIs preservados. Nada publicado/commit/push/tag.
Ao pedir navegação normal, encerrar turno; não aguardar pausas cronometradas.

## Reader48 / Gameplay19 — 03/11/2026

Usuário removeu repetir: L sem ação, API read_buffer rejeita repeat; I/K/direito
vertical um campo, J primeiro. Notícias J/L/direito horizontal AINDA pendentes,
assim como data ML automática ao entrar+exploração (decisão confirmada).
48limpa cor8hex/reset; ordem time/posição/pontos/saldo/demais; respostas do
DialogAgreement pelo cursor/dono nativo, sem exigir dono SWF igual à pergunta.
TeamSelectCommon271c8c8/c93200 limita polling/rebind automático às legendas
atuais, conserva exploração e outros donos/modal. Travessia estrutural permanece;
sem benchmark48/audição.433Lua/63Python+1skip/41contratosFL27/integração29.
Builder agora deriva build do bootstrap, ZIP48. Diário, notícias/data, cinco
times/rolagem e liga/participantes agrupados continuam abertos: coletar evidência
nativa antes de inventar campo/índice. Relatório docs/READER48-FL27-2026-11-03.pt-BR.md.
Não publicar/commit/push/tag. Ao pedir navegação normal, encerrar turno.

## Reader47 / Gameplay19 — 02/11/2026

Retorno46: endereço em áudio; Editar posição repetido após substituição; sons
param; slots ML sem identificação; sobrescrita sem pergunta automática; listas
lentas. Decisão explícita: atributos só na exploração; nome/situação automáticos,
classificação agrupada automática.47deferereads/decodificação e cache só síncrono;
SaveDataSelect thumbailNumber+conteúdo; DialogAgreement pergunta atual; foco de
plano antigo bloqueado em partida rodando; limpa endereços de painéis. Fonte
exata do endereço NÃO comprovada no log. DLL flaccess_audio_master recompilada
mesmaABI para sessão nativa recriada/target expirado e loops retomados. Prism/
OpenAL/SiderDLL/sons/perfis/INIs preservados. Gameplay19; câmeraJogador8 mantida.
431Lua/62Python+1skip/40contratosFL27/integração29/104gameplay/458orientação,
14política+COMfake e PCM/HRTF passaram; sem audição47 ou benchmark real.
Relatório docs/READER47-AUDIO19-2026-11-02.pt-BR.md. Relatos seguem pendentes
até retorno. Nada publicado/commit/push/tag; ao pedir teste normal, encerrar turno.

## Reader46 — retorno FL27, 01/11/2026

Atributos45 recuperados por confirmação do usuário; preservar. Nomes de times
substituídos por ZG/AT/MC, principal duplicado e submenu Football Life mudo
continuam REPRODUZIDOS45, sem aprovação46. Captura45 preservada em .test-temp.
46: lista nativa precede registros auxiliares, callback time captura mesmo com
flag antiga de plano; texto7 só com cursor/linha/dono atual; fala do título tem
fronteira única e entrega por âncora nativa; submenu grupo1 libera grupo0.
426Lua/61Python+1skip/39contratosFL27/integração29 passaram. Não é audição46.
Gameplay18/câmeraJogador8/corpo/sons/perfis/Prism/INIs/SiderDLL preservados.
Fonte canônica neste Git. Relatório docs/READER46-FL27-2026-11-01.pt-BR.md.
Desarme: usuário confirmou adversário com bola; escolha do novo aviso pendente,
sem mudança de raio/sons. Nada publicado/commit/push/tag. Ao pedir teste, encerrar.

## Jogador ID8 confirmado — 01/11/2026

Usuário confirmou que a partida da captura44 já usava câmera Jogador;
log registra ID8. Gameplay experimental18 liga essa câmera à direção real do
corpo (Player+61c), sem depender da matriz visual. ID9 do outro jogo não usado.
Reader permanece45.458contratos de orientação/104gameplay, integração29 e
renderWAV/HRTF passaram, incluindo troca câmera/corpo, matriz ausente, yaw
inválido e recuperação. Instalado com backup. Sem confirmação auditiva nova.
Novo relato: som de desarme lateral gira ao mover; pouca antecedência. Aberto.
Código atual é proximidade de bola com posse adversária, default2m/saída2.3m;
fonte sonora é a bola. Não prevê investida nem garante desarme. Sem mudar
raio/semântica do alerta enquanto se esclarece a situação descrita pelo usuário.
Nada publicado/commit/push/tag; configs/sons/DLLs preservados.

## FL27 e build45 — 01/11/2026

Jogo mudou para C:/Users/Diego/Documents/jogos/football life 2027; pasta antiga
football life deixou de existir. Fonte canônica é este checkout Git, modules/FlAccess.
Antes dos ajustes, instalação era44 e29 módulos idênticos: não era cópia antiga.
Relatos FL27: principal repete/corta tooltip; submenu Football Life e informações
do jogador sem leitura.45 adiciona travessia SWF tipada/guardada+98, autoridade
do text_item e fallback atrasado único. Pendentes até audição. Cursor42 preservado.
Câmera dos guias: nova base horizontal nas famílias provadas2/3/5/6, posse0/0/0.
Exceção automática Jogador AINDA NÃO ligada: ID FL não provado; não copiar9do
outro jogo. Demais câmeras conservam projeção anterior. Sem alterar câmera visual.
421Lua/39contratosEXE/61Python+1skip/453orientação/154legados/104gameplay,
integração29 e render realWAV/HRTF passaram;4matrizes antigas indisponíveis.
Relatório docs/FL27-BUILD45-2026-11-01.pt-BR.md. Nada publicado/commit/push/tag.

## Build44 confirmado e pacote portátil — 31/10/2026

Usuário respondeu “ta lendo certinho” à pergunta específica sobre classificação,
calendário e finanças. Itens51/55 confirmados nos fluxos testados; não inferir
aprovação de todos os cartões, principal ou desempenho. Pediu somente pacote
para outro Football Life. Alterações experimentais45 descartadas; fontes e
instalação continuam44. Exploração mantém um campo completo por passo.
Pacote FlAccess-0.2.0.zip na raiz do jogo; nada publicado/commit/push/tag.

## Reader build44 — retorno43 e exploração, 30/10/2026

Primeiro SP Football Life CORRIGIDO por confirmação real; preservar item4.
Liga Master/Rumo ao Estrelato repetem nome/cortam tooltip. Classificação só time,
calendário só meses e finanças sem agrupamento; cartões ML parciais. Sempre
chamar revisão de exploração; I/K/J/L/direito um campo completo por passo,
registro atual. Automático anuncia registro agrupado. Build44 adiciona módulo
reader_records (29 módulos); aliases num_* reais, calendário por Window+fc
com tipo/método verificados, pares rótulo/valor genéricos e itemName apresentado.
Principal com autoridade única/entrega preservada durante perda transitória.
419Lua/61Python/integração29componentes passaram; não equivalem a audição.
Finanças e cartões desconhecidos têm cobertura parcial NÃO comprovada. Manter
1/6/47/51/53/54/55/56 e demais pendências abertas, salvo4confirmado. Sem nova
DLL/hook, sem escrita de cursor42, Prism/gameplay/sons/perfis/SiderDLL preservados.
Backup local-backups/2026-10-30-before-reader44; captura43 preservada em tests/.
Relatório docs/READER-DEV44-2026-10-30.pt-BR.md. Nada publicado/commit/push/tag.
Ao pedir navegação normal, encerrar turno; sem pausas cronometradas/monitoramento.

# FLAccess 0.2.0 local — 30/10/2026

- Decisão do usuário: um FLAccess; leitor base obrigatório, sem liga/desliga.
  Controles individuais de sons/avisos são futuros. Sider DLL preservada.
- Fontes atuais: modules/FlAccess/*.lua, editadas diretamente. São28 módulos
  Sider reais; ordem em components.json e packaging/sider.ini.snippet.
  Não executar split_flaccess_sources.cjs/prepare_flaccess020.py novamente:
  registram migração inicial e rejeitam sobrescrever fontes mantidos.
- Recursos: content/FlAccess/{sounds,text,cameras}. Não precisam de cpk.root.
  Diretórios FlAccessReader/FlAccessGameplay são referência da transição;
  não ativá-los junto dos componentes0.2.0. Builders antigos são históricos.
- Build de pacote: tools/build_release.py. Instalação com backup/preferências:
  tools/install_flaccess.py. Não sobrescrever FlAccess.ini ou WAVs editados.
- Prism0.18.3 compilado do upstream70731bcb9837c90ff84ce401f244c0c4a8c7134c,
  fonte sem alterações; metadados/headers/licenças em modules/FlAccess.
-410 Reader modular por cópia/65Python(59+6)/104gameplay/191câmera e integração
  dos28 módulos/extração limpa/PCM real passaram. Não são audição no jogo.
- Preservar aprovações e pendências. Nenhuma intervenção no cursor42.
  Teste normal pelo usuário ainda necessário; ao pedir navegação, encerrar turno.
- Nada publicado/push/tag. Release0.1.9 imutável;0.2.0 apenas local.
  Detalhes docs/ARQUITETURA-0.2.0.pt-BR.md e IMPLEMENTACAO-0.2.0.pt-BR.md.

# Publicação e preservação

- Versão pública 0.1.9: Reader baseado na dev42 e Gameplay experimental16,
  ambos autorizados pelo responsável em30/10/2026. Preservar tags/releases anteriores.
- Publicar somente quando solicitado. Incluir DLLs/fontes/licenças necessárias no
  repositório e ZIP, conforme docs/PUBLICACAO.pt-BR.md. Estrutura livecpk/modules/sider.
- Editar engine/ e gerar com tools/build_reader_module.py e build_gameplay_module.py;
  pacote por tools/build_release.py. Preservar comportamento aprovado.
- Distinguir testes internos de audição real. Não publicar jogo, saves, logs,
  capturas brutas, preferências pessoais ou probes locais. A autorização de
  Gameplay experimental16 não inclui outros experimentos futuros automaticamente.
