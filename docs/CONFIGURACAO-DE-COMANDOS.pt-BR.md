# Configuração de comandos

O leitor acompanha a seleção original do jogo. Não move o cursor, não troca
botões e não altera configurações de controle.

- Na tela inicial, anuncia “Mover Jogadores” com seu valor quando disponível,
  e se Padrão, Alternativa ou Personalizar é o esquema aplicado.
- Dentro de Personalizar, lê o botão e a função atribuída na página atual de
  Ataque ou Defesa. Também identifica o botão marcado para troca quando esse
  estado é confirmado pelo controlador nativo.
- A exploração existente (I/K, J e analógico direito) permite consultar o
  desenho do esquema atual, um botão por vez, com as funções visíveis em
  ataque e defesa. Não despeja o desenho inteiro ao abrir a tela.

Os nomes dos botões seguem os símbolos exibidos pelo jogo. A fonte Xbox
compactada de SMK_Addcontrol é reconhecida; sua versão descompactada já
constava no leitor. A conversão existente para símbolos PlayStation permanece
disponível quando uma fonte PlayStation reconhecida estiver em uso. O tipo de
controle conectado, sozinho, não é usado para adivinhar os símbolos.

Esse reconhecimento também permite anunciar o botão junto de “Pular” quando
o ícone correspondente puder ser associado à legenda. Se o ícone estiver
indisponível ou ambíguo, continua lendo somente a legenda.

Validação: fonte Xbox do pacote local, cenários Lua com esquema aplicado,
movimentação por analógico, edição, troca pendente, diagramas Xbox/PlayStation,
cancelamento de fala antiga e botão de Pular; contratos do executável local.
Falta confirmar a tela ao vivo. Não foi testado um controle PlayStation físico.
