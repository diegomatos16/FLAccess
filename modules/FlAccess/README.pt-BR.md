# FLAccess 0.2.3 — experimental

Leitor e gameplay pertencem ao mesmo mod. Todos os componentes em
`components.json` devem carregar na ordem de `packaging/sider.ini.snippet`.
Leitor base obrigatório. A extensão experimental de audiodescrição tem opções
próprias para abertura e escalações. Replays estão desativados internamente; ver `docs/AUDIODESCRICAO-0.2.3.pt-BR.md` na raiz.
Somente reader_lifecycle registra eventos de leitura/painel; gameplay_lifecycle
registra atualização e reset da partida. Os outros módulos fornecem serviços.

Editar diretamente os arquivos Lua deste diretório: são fontes e módulos Sider
reais. Cada componente tem init(ctx) e return; não existe loader Lua próprio.
install(ctx) separa montagem dos serviços do início dos hooks/eventos e permite
testes dos mesmos módulos sem instalar hooks. Estado em ctx.flaccess.reader e
ctx.flaccess.gameplay conserva os antigos vínculos lexicais nesta primeira etapa.
Ainda existem dependências compartilhadas, explicitadas pelo prefixo shared.

Recursos editáveis: content/FlAccess/{sounds,text,cameras}. Não precisam de
cpk.root. FlAccess.ini reúne preferências do leitor e ajustes existentes de
desarme. Salvar opções do leitor preserva as demais linhas do arquivo.
bin contém Prism, OpenAL Soft e flaccess_audio_master. Licenças em licenses e
COPYING.OpenAL. state/live-layout.txt conserva validação local do gameplay;
arquivos TSV gerados em state não entram no pacote.

tools/build_release.py cria pacote local; tools/install_flaccess.py instala com
backup e preservação de preferências. scripts split_flaccess_sources.cjs e
prepare_flaccess020.py registram a migração inicial, não são builds cotidianos.
Os diretórios antigos FlAccessReader/FlAccessGameplay permanecem somente como
referência de transição; não ativar junto do FLAccess 0.2.0.

Prism: consultar PRISM-SOURCE.json para commit, versão e hash compilados.
Nenhuma promessa de correção dos relatos pendentes por esta refatoração.

Build44: reader_records.lua padroniza registros por seleção e campos reais.
Leitura automática usa registro agrupado; exploração I/K e direito vertical usa
um campo completo por passo. O termo exploração substitui navegação para esse
sistema; controles originais do jogo continuam navegação. J primeiro campo; repetir
removido, L sem ação. J/L para notícias pendente. Notas e limitações atuais em
docs/RELEASE-0.2.0.pt-BR.md; publicação Reader52/Gameplay19.
