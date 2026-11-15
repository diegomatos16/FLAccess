# Audiodescrição — 0.2.3

No painel FLAccess do Sider, a categoria **Audiodescrição** tem uma chave geral
e opções independentes para **Cenas de abertura**, **Escalações**.
Todas começam ligadas. Desligar uma opção cancela sua
fala e impede novas descrições desse tipo; as demais continuam disponíveis.
Preferências ficam no FlAccess.ini e são conservadas entre sessões.

A seleção de uniformes é lida ao passar pela opção, como parte da navegação.
Não tem chave própria e continua sendo lida com a audiodescrição desligada.

Escalações continuam até terminar os titulares por setor, mesmo depois de o
quadro desaparecer, conforme a preferência escolhida pelo usuário. Desligar
Escalações ou a chave geral cancela também essa leitura pendente.

A audiodescrição de replays está desativada internamente nesta versão. Não há opção no painel nem chave de INI para ativá-la. O código de pesquisa permanece na extensão e nos testes, para retomada futura; não anuncia “Replay” durante as partidas.

No plano de jogo, a exploração apresenta nome, força geral visível, estilo
de jogo, posição no campo e energia restante em porcentagem, nessa ordem.
Posições secundárias, quando verificadas, continuam entre estilo e posição
no campo. Overall e energia não são anexados à leitura automática do nome.
A indicação de lesão permanece quando confirmada nos dados nativos do jogador
selecionado. Valores indisponíveis são omitidos.

A classificação usa a linha selecionada no controlador da janela mais a
rolagem da tabela. O cursor da apresentação pode ficar na primeira linha e
não representa a seleção real. A fala aguarda a seleção estabilizar entre
quadros e não repete a tabela em atualizações sem mudança de seleção.
Depois de relato de lentidão e saltos com o mod, essa tela recebeu um caminho
próprio: leitura direta do registro selecionado, validação leve das janelas
e descarte de eventos redundantes dos textos da tabela. Exploração e diálogos
continuam sendo processados. O usuário confirmou no jogo a correção da lentidão e dos saltos de seleção.

Fonte da extensão: `modules/FlAccessOpeningTrace.lua`, carregada depois dos demais componentes. A extensão está incluída no pacote público e no bloco ordenado de 32 módulos.

Validação: testes Lua do leitor, cenários sintéticos da extensão, conferência das assinaturas no FL_2027.exe local e testes do instalador e do ZIP. Abertura, fotos e escalações foram experimentadas no jogo durante o desenvolvimento. Os cenários sintéticos de replay preservam a pesquisa sem habilitar a funcionalidade na distribuição.

## Reproduzir os testes

`python -m unittest discover -s tests -p test_opening_description.py` executa
os cenários sintéticos com Python e `lupa` (LuaJIT 2.1). Não requer jogo,
capturas, texturas, DLLs ou leitor de tela. Uma textura gerada pelo teste
exercita reconhecimento e invalidação sem distribuir recursos do jogo.

Para os contratos reais, defina `FLACCESS_TEST_EXE` com o caminho do executável
local e execute `python -m unittest discover -s tests -p test_native_contracts.py`.
Essa verificação lê as seções PE e confere as assinaturas da audiodescrição;
não modifica nem inicia o jogo. O teste sintético não substitui essa conferência
nem comprova o enquadramento durante uma partida.
