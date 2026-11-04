# Orientação do áudio por câmera — guia para reutilização

Estado em 2026-10-31. O usuário aceitou manter esta orientação após testar.
Não houve confirmação individual de todas as câmeras. Este guia explica o
comportamento e o algoritmo para adaptar a outro mod.

## Comportamento

A posição de escuta acompanha a cabeça do jogador controlado. A orientação dos
ouvidos é escolhida automaticamente:

| Visão | Orientação do áudio |
| --- | --- |
| Geral, incluindo Dinâmica ampla | Direção horizontal da câmera real do jogo |
| Jogador | Direção horizontal do corpo do jogador controlado |

Assim, numa transmissão lateral, um gol à direita da imagem soa à direita,
mesmo quando o jogador vira o corpo. A lateral distante pode soar à frente e a
próxima, atrás. Na câmera Jogador, virar o atleta muda esses lados: um gol antes
à frente pode passar para trás. A orientação acompanha a câmera efetiva; não
fixamos “gol adversário sempre à direita” no mundo.

O mod calcula posição relativa para seus próprios WAVs. Não captura nem copia
o estéreo original. A referência de posição fica no atleta, enquanto o áudio
original pode ter outras regras de mixagem; a correspondência não é uma cópia
exata. A câmera visual do jogo não é alterada.

## Dados que o outro mod precisa fornecer

Em cada atualização, obter novamente:

1. Estado de partida ativa/pausa/replay.
2. Posição do jogador controlado e da fonte sonora, na mesma unidade e eixos.
3. Tipo de câmera atual, identificado pela API ou enum real desse jogo.
4. Yaw da câmera real para visões gerais.
5. Direção real do atleta para a visão Jogador.

Usamos metros, plano horizontal XY e altura Z. Pitch e roll da câmera não
inclinam os ouvidos: uma câmera de transmissão inclinada para o gramado não
deve transformar todo o campo em uma fonte vertical. A altura real da bola
continua sendo considerada na posição da fonte.

## Algoritmo portátil

Para visão geral, com yaw em graus:

```text
a = yaw * pi / 180
frente = (cos(a), sin(a), 0)
direita = (-frente.y, frente.x, 0)
cima = (0, 0, 1)
```

Para a visão Jogador, usar a direção horizontal normalizada do atleta no lugar
de `frente`; calcular `direita` e `cima` da mesma forma.

Para cada fonte:

```text
delta = posiçãoFonte - posiçãoCabeçaDoJogador
OpenAL.x = produtoEscalar(delta, direita)
OpenAL.y = produtoEscalar(delta, cima)
OpenAL.z = -produtoEscalar(delta, frente)
```

No OpenAL, frente usa Z negativo. As fontes recebem coordenadas relativas ao
ouvinte (`AL_SOURCE_RELATIVE = true`); não aplicar essa transformação novamente
num segundo posicionamento do listener.

Exemplo: yaw = -90°, jogador na origem e gol em X positivo. A frente aponta
para Y negativo; a direita aponta para X positivo. Portanto, o gol soa à direita,
a lateral de Y negativo à frente e a de Y positivo atrás.

Validar números finitos, vetores unitários e ortogonalidade. Dados ausentes ou
ambíguos produzem silêncio, sem inventar direção ou conservar objetos inválidos.
Pausa/replay/fora de jogo ativo interrompem as fontes. Os sons de posse são
eventos únicos; não devem ser reiniciados em todo frame.

## Exceção para a bola com o próprio jogador

Quando a fonte real de posse indica `self`, `ball.wav` recebe posição relativa
`(0, 0, 0)`, centralizando o estéreo. A bola livre, com colega ou adversário volta
à posição espacial calculada. Não deduzir posse só pela proximidade da bola.
`gotBall.wav` também é centralizado. Os demais alertas mantêm seus alvos reais.

## Implementação específica do eFootAccess

- `gameplay_camera.lua`: seleção pura de base câmera/corpo e validação.
- `gameplay_adapter.lua`: leitura interna e emissão de vetores/nomes puros.
- `gameplay.lua`: transforma fontes para o espaço do listener e centraliza bola própria.
- `gameplay_runtime.lua`: atualiza a cada 50 ms e publica snapshots completos.
- `AudioBridge.cs`: WAV mono PCM16, OpenAL Soft 1.25.2, HRTF solicitado.

Getters refletidos utilizados:

```text
MatchDataStore:GetMatchCameraType() -> EMatchCameraType
MatchDataStore:GetCameraType() -> EPesCameraType
GameplayStatics:GetPlayerCameraManager(WorldContextObject, 0)
PlayerCameraManager:GetCameraRotation() -> FRotator
```

Comparamos nomes reais de enum. `EMatchCameraType::Player` ou câmera efetiva
`EPesCameraType::Player` selecionam corpo; os demais tipos reconhecidos usam yaw.
Na versão observada, Player é 9 nos dois enums; DynamicWide é Match4 e Wide é
Pes4. **Não transportar esses números para outro jogo.**

O WorldContextObject usado em produção é o ator selecionado, no mundo da partida.
MatchStatus é EngineSubsystem e não serve como contexto de mundo: retornava
câmera indisponível. Índice local 0 corresponde ao cenário testado; divisão de
tela precisa associação explícita ao viewport correto.

No eFootball observado, a malha olha para +Y local, embora o forward da raiz
venha de +X: o adapter converte isso. **Essa correção não é universal**; validar
os eixos reais da malha/cabeça do outro jogo antes de copiar.

Nenhum UObject, ponteiro de câmera ou ator permanece entre atualizações.
Persistem apenas metadados, números, nomes e caminhos. A fonte nativa de bola/
seleção do eFootball é específica do executável verificado; seu layout não faz
parte do algoritmo portátil e não deve ser reutilizado em outro mod/jogo.

## Validação realizada e roteiro para outro mod

Captura real da Dinâmica ampla: Match4/Pes4, yaw aproximadamente -89,956°,
pitch aproximadamente -21,471°. Log confirmou orientação por câmera em jogo.
HRTF informou status 1. O usuário respondeu “acho que funcionou, vamos deixar
assim”; isso não certifica individualmente cada câmera, intervalo ou situação.

Para validar uma adaptação, jogar normalmente com uma fonte à direita, esquerda,
frente e atrás; virar o atleta em visão geral; depois testar a visão Jogador.
Conferir troca de câmera, lados no intervalo, pausa e retomada. Registrar a
leitura interna, a aceitação pelo backend e o que a pessoa realmente ouviu
separadamente. Testes de vetores não substituem o teste auditivo.
