# Investigação do menu de áudio do Football Life 2026

## Resultado

A tela principal de áudio contém esta sequência na tabela de idioma:

1. `Música`
2. `Comentário`
3. `Configurações de volume`
4. ` ` (texto vazio)
5. ` ` (texto vazio)

Os itens 4 e 5 não têm nomes escondidos. O Football Life conserva dois slots
na interface, mas substitui os textos por espaços. Por isso o mod não tem texto
real para enviar ao leitor de telas.

## Verificação

Foi extraído `bra/string/all.str` de `Data/dt20_bra_x64.cpk`, removido o
contêiner WESYS/zlib e comparada a sequência com `eng/string/all.str` de
`Data/dt20_eng_x64.cpk`. A versão inglesa tem exatamente o mesmo resultado:
`Music`, `Commentary`, `Volume Settings`, espaço, espaço.

Conclusão: não inventar rótulos para esses dois slots. Eles devem permanecer
silenciosos/ignorados enquanto o Football Life não lhes atribuir uma função.
