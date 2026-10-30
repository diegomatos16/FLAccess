# FlAccessReader

Leitura de menus, seleção, revisão de jogadores e painel do Sider. Independente
do FlAccessGameplay. Ativar com `lua.module = "FlAccessReader\FlAccessReader.lua"`.

Assets: `livecpk/FlAccessReader/text/pt.tsv`, `en.tsv` e `styles-pt.tsv`/`styles-en.tsv`.
Motor: `modules/FlAccessReader/FlAccessReader.lua`; Prism em `modules/FlAccessReader/bin/`.
Configuração pessoal: `modules/FlAccessReader/FlAccessReader.ini`, criada no uso.
Fonte mantido em engine/*.lua, concatenado em ordem lexical pelo script
`python tools/build_reader_module.py`. Editar partes e gerar o arquivo final;
`--check` detecta arquivo desatualizado. O Sider carrega somente o Lua gerado.

O núcleo Sider compatível está em `sider/sider.dll` no ZIP. Copiar para a raiz do
SiderAddons conforme `sider/INSTALL.pt-BR.md`. Não carregar também `FLAccess.lua`
antigo: isso duplicaria callbacks e falas.

Versão pública0.1.9, baseada na dev42. Releases anteriores preservadas. Assinaturas e
vínculos foram investigados no FL 2026; FL 27 exigirá verificação própria.

Y/Triângulo: título automático. Revisão I/K e direito cima/baixo: apenas dados
do jogador, um rótulo e valor por passo; sem Ajuda, Voltar ou título na sequência.

I/K e direito cima/baixo também revisam textos úteis nas demais telas reconhecidas:
notícias, listas, perguntas e mensagens. Perguntas/mensagens sem respostas/botões
no buffer; responder pelos comandos originais. J primeiro/L repete. Legendas de
comandos ficam fora dessa revisão. Cobertura depende dos componentes nativos legíveis.

Mensagens: setas selecionam normalmente; leitor anuncia título/conteúdo do registro
atual. I/K e direito revisam apenas essa mensagem em ciclo. Listas de jogadores:
revisão só da linha atual e dados vinculados, sem juntar outros jogadores.
Carregamento nativo reconhecido por mais de3segundos: aviso único “Carregando tela”.
Não cobre um bloqueio completo do callback de render nem toda tabela desconhecida.

Registros estruturados: setas anunciam dados agrupados da linha/dia atual;
I/K e DIREITO revisam seus campos rotulados, em ciclo. Classificação e calendário
usam seletor interno quando existir; colunas extras precisam de rótulos reais.
Registros ambíguos não liberam leitura da tabela inteira. Cobertura real pendente.
Desempenho: leituras repetidas reutilizadas apenas na fase síncrona atual; estatísticas
reader-work no log. Erro de conteúdo não troca NVDA por SAPI repetidamente.

Tooltips: HelpBox/descrições atuais seguem canal comum após a opção; respeita Ler
tooltips e controles originais. Primeiro item usa o mesmo par nome/descrição e
publicador das outras opções. Países seguem ID filtrado e nome na base nativa,
sem depender de legenda do continente. Classificação reconhece
campos de vitórias/empates/derrotas/pontos/gols vinculados. Audição real pendente.
Fala longa com falha de conversão pode usar fragmentos UTF8 no mesmo leitor;
falha persistente é registrada sem alternar SAPI e NVDA repetidamente.

Fila publicada uma vez após atualizar foco, até duas tentativas de fala
por callback. Cancelamento de país/tooltip libera nova tentativa.
Falha de fragmento não confirma mensagem
inteira. Comunicação Prism permanece síncrona em Lua por escolha do usuário;
chamada lenta ainda pode atrasar um quadro. reader-work separa custo de voz/foco.
Testes internos não encerram os relatos reais de lentidão ou conteúdo ausente.

Dev42 corrige erro de endereço cdata que abortava leitura no principal,
classificação e calendário. Testes anteriores não cobriam esse tipo de ponteiro.
Validação agora usa RPM/renderizadores reais no processo de teste; confirmação
no jogo ainda necessária. Nenhuma intervenção no cursor foi reintroduzida.
