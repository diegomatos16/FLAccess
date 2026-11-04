# Experimento de áudio 3D

Experimento local autorizado em 12/10/2026. Sem controles de usuário.

## Resultado comprovado

O módulo `FLAccess_audio_probe.lua` foi executado dentro de `FL_2026.exe`, pelo
Sider 7.3.3 e LuaJIT x64. OpenAL Soft 1.25.2 confirmou:

- `HRTF enabled=1 status=1`, perfil `Built-In HRTF`.
- `ball.wav`: PCM16 mono, 44100 Hz, 14994 amostras.
- `alertSidelines.wav`: PCM16 estéreo, 44100 Hz, 94118 quadros;
  convertido para mono em memória pela média dos canais.
- Três fontes em loop, com estado `AL_PLAYING` verificado a cada dois segundos.
- Atualização de posição e volume sem reiniciar buffers.
- Sequência de 20 segundos concluída e recursos de áudio liberados.

Esse teste usa **posições simuladas**, não acompanha a bola real. São oito
segundos de bola circulando em torno do ouvinte, seis de lateral esquerda
aproximando/afastando e seis de lateral direita. Ouvinte fixo olhando para -Z.
Ganhos máximos: bola 0,25; lateral 0,30. Doppler e atenuação automática desligados.
O teste começa 15 segundos após carregar o módulo e consome um marcador ASCII
`modules/FLAccess-Audio/armed.txt` com conteúdo `armed`.

## Leitura no treino após reinício

A captura interna corrigida funcionou na sessão iniciada em 12/10/2026 às
22:19:36 (horário de São Paulo), PID 35528. Foram comparadas 50 amostras de
estado parado e deslocamento. Endereços abaixo pertencem **somente a essa
sessão**, não são endereços fixos para implementar o radar.

- Bola: dados da entrada de registro em `0x1fa68b00`, XYZ em `+0x10`, `+0x14`,
  `+0x18`. Inicial `(-46,833; 0,109; 15,667)`, final
  `(30,416; 0,112; -17,750)`. X/Z variaram pelo campo; Y manteve altura da bola.
- Jogador em movimento: dados `PlayerMove` em `0x5d571d80`, XYZ em `+0x0c`,
  `+0x10`, `+0x14`. Inicial `(-47,333; 0; 15,667)`, final
  `(31,275; 0; -11,882)`. Só um registro tinha posição ativa nesse treino.
  Isso ainda não identifica o jogador controlado numa partida com 22 jogadores.
- Campo: dados em `0x5d26e450`; valores de meia extensão em `+0x04` e `+0x08`:
  52,56 e 34,06. Há margem de 0,06 em relação a 52,5 e 34; validar significado
  exato da margem antes de adotar limiar junto à linha pintada.
- Câmera: dados em `0x1fa6fdb0`. Matriz candidata começa em `+0x0c`.
  Direita proporcional a campos `0x0c/0x1c/0x2c`; cima a `0x10/0x20/0x30`;
  frente a `0x18/0x28/0x38`. Nas 50 amostras, comprimento de frente ficou entre
  0,99999990 e 1,00000009; maior produto escalar absoluto entre eixos
  normalizados foi 0,0000000234. Estrutura é consistente com matriz de projeção
  e visão. Interpretação precisa confirmação auditiva com câmeras diferentes.

O teste demonstrou separadamente reprodução HRTF e leitura espacial dinâmica.
**Os sons ouvidos ainda eram simulados**; não há radar real integrado nesta etapa.
Pendente para próximo experimento: resolver referências por sessão, identificar
jogador controlado e conectar os três loops aos dados da partida.

Capturas locais: `FLAccess/gameplay-still.tsv`, `FLAccess/gameplay-moving.tsv`.
Não incluir dumps de memória na distribuição. A captura é limitada e se encerra.

## Investigação das posições

`FLAccess_gameplay_probe.lua` faz leitura de memória do próprio processo,
distribuída entre quadros, sem instalar hooks ou escrever memória do jogo.
Procura vtables encontradas por RTTI no executável local: `BallInfoRef`,
`PlayerInfoRef`, `PlayerMoveRef`, `CameraInfoRef`, `CameraTargetInfoRef`,
`FieldInfoRef`, `BallControl`, `InplayCamera` e `Player`.

Limites: 1 MiB por passo, intervalo mínimo de 20 ms, até 2048 MiB e 256
candidatos. Depois, até 30 capturas em intervalos de três segundos.
Saída: `modules/FLAccess-Audio/gameplay-snapshots.tsv`. Identificar tipo ou
encontrar floats **não comprova coordenadas**. Comparar parado, deslocamento,
passe e mudança de câmera antes de ligar o radar aos dados.

A ferramenta externa `probe_gameplay_memory.py` encontrou os tipos no arquivo,
mas `OpenProcess` retornou acesso negado porque o jogo está elevado. A captura
interna pelo Sider evita depender de acesso externo.

## Referência espacial acordada

Ponto de escuta no jogador controlado; eixos de frente/direita derivados da
câmera. Transformar deslocamento da bola para esses eixos. Para cada lateral,
usar ponto mais próximo da linha e ganho suavizado pela distância à linha.
Assim, câmera de frente coloca laterais nos lados; câmera de transmissão pode
colocá-las à frente/atrás ou nas diagonais. Eixos, escala do campo e identidade
do jogador controlado ainda precisam validação no jogo.

## Instalação local e retirada

Na sessão de teste, `SiderAddons/modules/env.lua`, módulo de diagnóstico já
carregado, recebeu temporariamente o experimento para permitir recarga com
Shift+R. Backup: `FLAccess/backups/2026-10-13-audio-probe/env.lua`.
Backup restaurado após coleta; próximo início carrega diagnóstico original.
Os arquivos locais
de áudio ficam em `SiderAddons/modules/FLAccess-Audio/`; nenhuma alteração no
executável é necessária.

OpenAL Soft foi obtido do fornecedor:
https://openal-soft.org/openal-binaries/openal-soft-1.25.2-bin.zip
Licença LGPL fornecida em `COPYING` junto da DLL. A DLL e os WAVs ficam fora da
distribuição do projeto durante este experimento.
