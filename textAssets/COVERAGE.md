# Cobertura da extração

Execução concluída em **20 de setembro de 2026**.

## Totais

- 39.019 arquivos físicos inventariados.
- 78 arquivos CPK abertos e indexados.
- 110.753 membros internos de CPK inventariados.
- 27.887 membros internos analisados como possíveis fontes de texto.
- 650.120 textos únicos.
- 6.424.814 ocorrências com origem e offset.
- 18 idiomas de localização.
- 17 executáveis/DLLs analisados por seções PE.

## CPK

- 72.722 membros sem formato textual conhecido: inventariados.
- 75.514 membros de mídia: inventariados, sem interpretação textual.
- 80 membros acima de 64 MiB: inventariados, sem leitura integral.
- `.str` WESYS/zlib: descompactado e analisado.
- CRILAYLA: descompactado pela biblioteca `pes-file-tools` quando indicado no
  índice CPK.

## Executáveis

`FL_2026.exe`, `PES6.exe`, launchers, configurações e DLLs foram incluídos.
No formato PE, somente seções de dados/recursos com entropia aceitável são
varridas; código, overlay e seções empacotadas de alta entropia ficam
registrados em `files.csv`. Isso evita milhões de falsos textos produzidos por
bytes comprimidos.

## Erros

Dois arquivos de dependência de pesquisa não puderam ser lidos por permissão do
ambiente: `FLAccess/.python/pefile.py` e `FLAccess/.python/peutils.py`. Eles não
fazem parte dos assets do jogo. Todos os CPKs, executáveis do jogo e conteúdos
runtime foram processados.

## Validações

- Banco SQLite: `PRAGMA quick_check` retornou `ok`.
- `Configurações de volume` foi encontrado em
  `Data/dt20_bra_x64.cpk`, membro `bra/string/all.str`, offset `1304349`, papel
  `control`.
- Textos `.str` registram extração `cpk/wesys-zlib`.
- Nenhuma assinatura comprimida `WESYS` foi catalogada como texto de `.str`.

Classificação de papel é heurística. Use contexto/foco de widget do FLAccess
como confirmação antes de anunciar automaticamente um texto ambíguo.
