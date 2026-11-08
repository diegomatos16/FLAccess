# Ideias de acessibilidade para o eFootball

Este guia reúne comportamentos e decisões do FLAccess que podem orientar um mod
de eFootball. Cada jogo precisa fornecer seus próprios sinais de foco, estado
da partida, posição, câmera e posse.

## Menus e navegação

- Ler automaticamente o item que recebe foco. Para um seletor, juntar rótulo
  e valor, como “Dificuldade, Profissional”. Ao navegar rápido, descartar
  leituras antigas que ainda estiverem na fila.
- Anunciar o título quando a tela muda. Tratar diálogos como uma camada
  separada. Ler a mensagem e a opção focada, como “Sim” ou “Não”, sem puxar
  itens do fundo. Informar carregamento uma vez quando o jogo indicar que começou.
- Ler a descrição da opção selecionada após o rótulo, com ajuste para desligar
  descrições. Cancelar a descrição pendente se o foco mudar.
- Oferecer exploração manual para painéis com informação sem foco próprio.
  Cada passo lê um campo completo, como “Altura, 180 centímetros”, ou um
  registro completo, como o jogador selecionado e sua força geral. Manter a
  exploração dentro do painel atual.
- No Plano de Jogo, anunciar Titular, Reserva ou Não relacionado ao cruzar a
  divisão. Usar a vaga real no elenco e a regra da partida. Depois ler camisa
  e nome, por exemplo “10 Ronaldinho”.
- Usar o leitor de tela ativo para fala. Se houver voz alternativa, oferecer
  ajustes de velocidade, volume e uma amostra. Deixar a navegação com o
  controle funcionar sem exigir alternância para o teclado.

## Informação em partida

- Permitir consultar tempo e placar sob demanda, com o mandante primeiro.
- Anunciar o jogador controlado na troca, se a opção estiver ligada. Para o
  portador da bola, oferecer desligado, a cada mudança ou intervalo ajustável.
  Com camisa ligada, falar número antes do nome. Se ambos os anúncios
  identificarem o mesmo jogador, fazer uma fala só.
- Usar a posse informada pelo jogo para separar bola própria, do companheiro,
  adversária e solta. Ganho e perda podem ter sinais curtos. Um passe que fica
  com o mesmo time merece um sinal próprio quando essa continuidade for
  confirmada.
- Anunciar substituições efetivas com quem sai e quem entra, para os dois
  times. Mudança de formação ou troca de posição dentro do campo tem outro
  significado.

## Áudio para orientar movimento

- Posicionar os sinais a partir do jogador controlado, com áudio binaural e
  amostras mono. Centralizar o radar da bola sob posse própria.
- Para a bola, conferir se a direção bate com a do chute e do quique do jogo.
  Na câmera Jogador, o FLAccess usa o eixo da câmera para esse radar. A
  coincidência com o som nativo precisa ser ouvida em partida.
- Usar linhas laterais, linhas de fundo e gols como referências de proximidade.
  Manter a orientação previsível ao girar o atleta e atualizar o gol de ataque
  quando os times trocam de lado. Conferir a correspondência com o analógico
  em cada família de câmeras.
- Tratar o sinal de desarme como aviso de oportunidade. Tocar quando um
  adversário está com a bola baixa e próxima. Usar um raio de saída um pouco
  maior para evitar cortes na borda. O som de ganho de posse é a confirmação
  de que a posse mudou.

## Radar de jogadores

No FLAccess, o radar toca durante a posse do seu time. Assim, na defesa,
os sinais da bola e do desarme ficam em destaque. Cada sinal de jogador vem da
posição do atleta, com a mesma referência direcional usada pelo radar da bola.

- **Livre.** Companheiro com espaço, sinal de vento.
- **Marcado.** Companheiro com adversário próximo, sinal de batida em porta.
- **Adversário.** Sinal curto com timbre de erro, distinguível dos outros dois.

A primeira classificação usa distância entre o companheiro e o adversário
mais próximo. No FLAccess, a marcação entra até 3 metros e sai acima de
3,5 metros. Isso é uma aproximação de pressão. Linha de passe, interceptação
e direção da corrida são possíveis refinamentos a testar separadamente.

O jogador escolhe **Por distância** ou **Por número de jogadores**. O raio
geral vale nos dois modos. Por distância, cada jogador elegível pode soar.
Por número, tocam só os mais próximos de cada grupo, até o limite escolhido.
Exemplo com raio de 20 metros: até três marcados, um livre e dois adversários.
Ao trocar de modo, preservar os limites configurados.

Intercalar os pulsos para evitar que os sons se encubram. Dar uma primeira
oportunidade aos alvos próximos e deixar os demais tocar na sequência.
Em um raio cheio, o intervalo entre repetições de cada atleta pode crescer.
Encerrar sinais ao pausar, trocar de contexto ou perder as referências válidas.

## Configuração no eFootball

Levar as opções para um painel acessível do próprio mod, acionável por teclado
e, se houver entrada livre, pelo controle. Também é possível manter as
preferências em arquivo. O fluxo independe do painel do Sider.

- Radar geral ligado ou desligado, modo e raio.
- Limites de marcados, livres e adversários no modo por número.
- Liga/desliga, volume e amostra do som fixo de cada grupo.
- Volumes independentes para bola, linhas, gols e desarme. Acompanhar o mudo
  do jogo e preservar os ajustes ao desativar uma categoria.
- Controles de fala, descrições, frequência de anúncios e camisa. Ler o valor
  atual ao entrar no ajuste, anunciar alterações e permitir restaurar padrões.

Validar com navegação normal de menu, um passe lateral na câmera Jogador,
troca de lado no intervalo e um lance com companheiros e adversários
aglomerados. Conferir também pausa e retomada. Testes de direção e seleção
offline conferem a lógica. A escuta em partida confirma se os sinais são
distinguíveis e correspondem ao movimento.
