# FLAccess 0.2.0 — divisão e unificação

Decisões alinhadas com Diego em 30/10/2026. Trabalho local, sem publicação.

## Contrato

- Um projeto e pacote FLAccess reúne leitor e gameplay.
- Leitor base obrigatório. Não criar opções para desligar partes do leitor.
- Controles individuais de sons, anúncio de posse e outros avisos são futuros.
- Preservar regras, controles, preferências e aprovações existentes. Refatoração
  não encerra problemas pendentes nem equivale a audição no jogo.
- Preservar Sider DLL, executáveis e demais mods. Apenas referências FLAccess no
  sider.ini mudam para carregar os componentes. Sem require/dofile/loadfile.
- Não reintroduzir intervenção no cursor ou resultado de janelas (item 42).
- Prism continua síncrono em Lua, conforme decisão anterior. Atualizar biblioteca
  oficial e conferir ABI, arquitetura, hash e licenças. Sem nova DLL de fala.

## Organização no padrão PES/Sider

`modules/FlAccess` contém módulos Lua, configuração, DLLs e licenças.
`content/FlAccess` contém WAVs, catálogos de texto e perfis de câmera editáveis.
LiveCPK é reservado a substituições reais de arquivos carregados pelo jogo;
os atuais WAV/TSV são lidos diretamente e não precisam de cpk.root.
Pasta sider do pacote conserva o núcleo compatível atual.

Referências: https://mapote.com/doc/sider/sider7/readme.html,
https://mapote.com/doc/sider/sider7/scripting.html e
https://github.com/pes-modding/kitserver-sider-module.
APIs conferidas também no código local da versão Sider instalada.

## Divisão incremental

Núcleo comum mantém versão, caminhos e ordem de inicialização. Serviços são
publicados em ctx.flaccess, seguindo padrão das bibliotecas CommonLib/nesalib.
Dependência ausente ou ordem incorreta gera erro explícito, sem iniciar um leitor
parcial. Só o componente responsável registra cada callback.

Leitor: estado inicial, memória/Prism, textos/configuração, fila de fala,
semântica de telas, revisão, árvore nativa, janelas nativas, apresentação,
jogadores, controles, observações, resolução de textos, foco, quadro e ciclo de
vida. Primeira etapa conserva as fronteiras dos 16 fontes existentes, expondo o
estado antes lexical de forma explícita e verificável. Não alegar que isso já
elimina todo acoplamento entre componentes. Extrações posteriores por domínio
devem preservar vínculos nativos e fila única.

Gameplay: política de áudio Windows, registro nativo, perfis/projeção de câmera,
estado compartilhado, regras de avisos, leitura da partida, reprodução espacial,
diagnóstico e ciclo de vida. Extrair funções sem alterar regras de posse,
orientação, distâncias, pausa e reentrada. Uma atualização continua produzindo
um estado de partida para os efeitos, sem leitores independentes por som.

Um painel FLAccess representa configuração e revisão. Componentes de suporte
não criam painéis próprios. Cada módulo é Lua normal com init(ctx)/return.

## Validação e instalação

1. Backup dos fontes, ferramentas e sider.ini anteriores.
2. Build determinístico, sintaxe LuaJIT, escopos/sombreamento e ordem de carga.
3. Testes comportamentais existentes e testes dos módulos reais instaláveis.
4. Integração no sandbox equivalente ao Sider: callbacks, Prism, textos,
   dependências, pausa/reset e composição dos motores.
5. Pacote local e instalação no SiderAddons; migração preserva INIs anteriores.
6. Verificar hashes instalados, referências no INI e Sider DLL preservada.
7. Navegação/audição normal pelo usuário; não usar pausas cronometradas.
   Encerrar turno ao solicitar esse teste. Testes automatizados não comprovam
   FPS, ausência universal de crashes ou funcionamento audível de todas as telas.

Release/tag 0.1.9 e seus arquivos permanecem intactos. Não publicar 0.2.0 sem pedido.

Build44 acrescenta reader_records.lua antes de reader_review. Serviço comum de
registros usa seleção/colunas nativas ou rótulos/valores vinculados. Total29
componentes. Exploração sempre um campo completo por passo do registro atual;
navegação continua designando controles originais do jogo.

Build51 separa reader_groups (semantics → groups → records → review) e
reader_lists (controls → lists → observations). Total31 componentes nativos.
Listas validam seleção/cabeçalhos sem reconstruir membros em quadros estáveis;
agrupamentos usam um motor comum de rótulo/valor/título com dono nativo provado.
Detalhes do jogador só na exploração, um campo por passo; título real acompanha
o primeiro campo ao entrar no grupo. Ver relatório READER51-LISTAS-GRUPOS.
