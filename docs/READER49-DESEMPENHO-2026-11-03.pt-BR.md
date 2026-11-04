# Reader49 — desempenho das listas

Usuário confirmou correções48 de Configurações (sufixo indevido) e Sim/Não.
Restante continua aberto: Master Liga e listas deixam o jogo muito pesado.
Prioridade deste ajuste é reduzir trabalho no caminho automático; não declarar
notícias/data/Diário/rolagem resolvidos por esse trabalho.

Capturas preservadas em `.test-temp/fl27-audit/components48-return.log` e
`sider48-return.log`, antes de qualquer instalação. Log registra médias de
21,665ms/527,2 cópias de memória por quadro em um trecho e
20,105ms/716 cópias em outro. A captura estava ativa e seu custo está incluído;
não atribuir todo o tempo a uma função sem medição por etapa.

## Mudanças

- `native_field_label` verificava apresentação e identidade de cada texto
  histórico antes de testar se era descendente da opção atual. Agora testa a
  árvore primeiro; somente candidatos do componente acessam memória. Mantém
  rejeição de rótulos/valores ambíguos e wrappers desconhecidos.
- `collect_record_nodes` elimina uma segunda passagem por todo o modelo
  histórico. Um campo só é elegível se já pertence aos membros nativos visitados
  na primeira passagem; não perdia informação ao eliminar esse trabalho.
- Metadados MSVC e vínculo de recurso usam o mesmo cache de escalares da fase
  atual. Leituras adjacentes compartilham blocos protegidos de128bytes;
  `ReadProcessMemory` e limites permanecem. Nada é guardado entre callbacks.
- Uma árvore recém-percorrida no mesmo callback pode fornecer a subárvore
  selecionada. Evita percorrer novamente seus holders. Proibido derivar de cache
  de outro quadro ou percurso truncado; próximo callback revalida objetos.
- Log de custo passa a separar janelas, textos, apresentação e captura, além
  de foco e fala. Assim um próximo resultado ruim identifica a etapa restante.

Sem escrita no cursor, envio de controles ou alteração da lógica do jogo.
Leitor base segue obrigatório; atributos continuam somente na exploração,
classificação automática agrupada. Gameplay19, Prism, DLLs e recursos preservados.

## Evidência e limites

436 verificações Lua. Novo caso com1200 legendas de outras áreas reproduz o
problema no48:1200 verificações de apresentação alheias.49faz zero, mantendo
o mesmo vínculo rótulo/valor. É teste controlado, não FPS medido no jogo.

Novo teste de memória Windows: dois nomes inline usam3 cópias totais em uma
fase; cabeçalho compartilhado e nomes repetidos sem nova cópia. Após mudança
de fase, PAGE_NOACCESS é rejeitado. Novo teste de árvore exige uma travessia
para ancestral+subárvore na mesma fase e revalidação na próxima.

Integração29 componentes,16 eventos,23 registros,120 quadros, Prism nativo.
64 testes Python:63 passam,1 ignorado por captura histórica indisponível.
41 contratos de leitura do FL27 incluídos. Falta confirmação de desempenho real.

## Master Liga — achados, ainda pendentes

Captura tem `news_title`, `news_text_0/1/2`, `journal_text_0/1` e `p_journal`.
Notícias mudaram de conteúdo durante a sessão. Ainda falta provar o controlador
e o conjunto de notícias para J/L anterior/próxima; não inventar uma lista com
histórico de textos antigos. I/K permanecem um campo completo por passo.

`schedule_date` aparece em várias partidas (1,8,15,22/2/2026); não é prova da
data atual. A decisão permanece: data ao entrar e na exploração.
Cartões sem texto do MainMenuML continuam com seleção nativa válida; falta
provar ligação entre cada cartão e seu conteúdo. Alcance dos cinco times e
agrupamento das informações de liga permanecem abertos.

Fonte canônica `C:/Users/Diego/git/diegomatos16/FLAccess/modules/FlAccess`.
Instalação49 no Sider do FL27 com backup; sem rearmar captura de componentes
pesada para a próxima avaliação de velocidade. Arquivo48 preservado.
Sem publicação, commit, push ou tag.

Instalação concluída; backup
`local-backups/flaccess020-install-20261103-005915-422929`. Conferidos29 módulos
idênticos à fonte;30 recursos e3DLLs iguais ao backup; FlAccess.ini/sider.ini
idênticos em bytes. Marcador de captura continua `consumed`, sem rearmar.
Pacote local atualizado em `release/0.2.0-local/FlAccess.zip`, metadados build49.
