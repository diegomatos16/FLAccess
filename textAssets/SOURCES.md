# Fontes técnicas e comunitárias

## Ferramenta usada

- [the4chancup/pes-file-tools](https://github.com/the4chancup/pes-file-tools):
  implementação aberta usada para ler tabelas CPK, descriptografar `@UTF` e
  descompactar CRILAYLA. A cópia local está em
  `FLAccess/reference/pes-file-tools`, commit
  `9cdfcc5ce902a8908a851787298cf8f79862a3c6`.
- O mesmo projeto contém suporte WESYS/zlib, usado antes da leitura dos `.str`.

## Confirmação do formato e localização

- [Rigged Wiki — PES 2021 Game Tips](https://implyingrigged.info/wiki/Pro_Evolution_Soccer_2021/Game_Tips):
  confirma `Data/dt20_eng_x64.cpk`, `eng/string/all.str` e a necessidade de
  remover zlib antes de processar tabelas de texto.
- [Rigged Wiki — PES 2016 Strings](https://implyingrigged.info/wiki/Pro_Evolution_Soccer_2016/Strings):
  documenta a família de formatos: arquivos `.str` dentro de CPK, organizados
  em blocos nomeados; versões modernas mantêm `all.str`, `common.str` e
  `staff_list.str`. O catálogo não assume que todo pacote Football Life tenha
  os três arquivos; usa o inventário real de cada CPK.

## Ferramenta avaliada e não usada

- PES 2021 STR Editor, de Devil Cold52: abre CPK/STR e exporta textos, mas a
  distribuição encontrada é binária fechada, hospedada por terceiros e traz
  aviso sobre detecção antivírus. Não foi baixada nem executada. O pipeline
  aberto e auditável acima já cobre extração necessária.

Consultas feitas em 20 de setembro de 2026. Fontes comunitárias servem para
orientar interpretação; offsets e conteúdo do catálogo vêm exclusivamente dos
arquivos locais desta instalação.
